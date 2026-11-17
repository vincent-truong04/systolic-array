#!/usr/bin/env python3
"""Summarize power_windows.tcl output: per-window totals (from <win>.rpt) and a per-function
breakdown from <win>_inst.json, grouping instances by name (flat netlist, so names are the
only link to the RTL). Also energy metrics for the dense/sparse windows.
Usage: power_groups.py <power dir with zd/ and/or sdf/> <windows json> [6_final.v]
The optional netlist lets ICG cells (sky130 dlclkp, D-017) be counted as their own group;
without it they fall into "combinational logic (_N_)". A missing zd/ (or sdf/) dir is skipped.
"""
import json
import re
import sys
from pathlib import Path

GROUPS = [  # (label, regex on the instance name; first match wins)
    ("clock tree (clkbuf + clkload)", r"^(clkbuf|clkload)"),
    ("PE acc regs (64 x 32b)",        r"u_pe\.acc"),
    ("PE prod_q regs (64 x 16b)",     r"u_pe\.g_pipe\.prod_q"),
    ("PE a_out/b_out regs",           r"u_pe\.(a_out|b_out)"),
    ("PE flag regs",                  r"u_pe\.(first_out|valid_out)"),
    ("skew regs",                     r"u_skew_"),
    ("I/O regs (a_q, b_q, out_*)",    r"^\\?(a_q|b_q|out_data|out_row|out_valid|in_ready|v_q|f_q)"),
    ("control regs",                  r"^\\?(cnt|state|drain_q)"),
    ("repair/IO buffers",             r"^(place|rebuffer|split|hold|input|output|wire|max_length)"),
    ("combinational logic (_N_)",     r"^_\d+_$"),
]


ICGS = set()


def group_of(name):
    if name in ICGS:
        return "clock gates (ICG dlclkp)"
    n = name.replace("\\", "")
    for label, rx in GROUPS:
        if re.search(rx, n):
            return label
    return "other"


def totals(rpt):
    t = {}
    for line in open(rpt):
        f = line.split()
        if f and f[0] in ("Sequential", "Combinational", "Clock", "Total") and len(f) >= 5:
            try:
                t[f[0]] = [float(x) for x in f[1:5]]
            except ValueError:
                pass
    return t


def main(pdir, wjson):
    pdir = Path(pdir)
    w = json.load(open(wjson))
    meta = w["meta"]
    wins = ["idle", "dense", "sparse", "drain1", "drain2", "drain3", "drain4"]
    modes = [m for m in ("zd", "sdf") if (pdir / m / "dense.rpt").exists()]
    res = {m: {x: totals(pdir / m / f"{x}.rpt") for x in wins} for m in modes}
    mw = lambda v: f"{v * 1e3:7.2f}"

    print("## Totals at tt_025C_1v80 (mW): total | sequential | combinational | clock | switching share")
    for m in modes:
        for x in wins:
            t = res[m][x]
            T = t["Total"]
            print(f"{m:3s} {x:7s} {mw(T[3])} | {mw(t['Sequential'][3])} | {mw(t['Combinational'][3])} | "
                  f"{mw(t['Clock'][3])} | sw {T[1] / T[3] * 100:4.1f}%  leak {T[2] * 1e6:.3f} uW")
    for m in modes:
        d = [res[m][f"drain{i}"]["Total"][3] for i in range(1, 5)]
        print(f"{m} drain mean {sum(d) / 4 * 1e3:.2f} mW (min {min(d) * 1e3:.2f}, max {max(d) * 1e3:.2f})")

    print("\n## Energy (window = 4 back-to-back job periods)")
    cyc = 4 * meta["period_cycles"]
    t_s = (w["dense"][1] - w["dense"][0]) * 1e-9
    macs = 4 * meta["macs_per_job"]
    print(f"window {cyc} cycles = {t_s * 1e9:.0f} ns, {macs} MACs, array busy {meta['K']}/{meta['period_cycles']} "
          f"= {meta['K'] / meta['period_cycles'] * 100:.1f}% of cycles")
    for m in modes:
        idle = res[m]["idle"]["Total"][3]
        for x in ("dense", "sparse"):
            p = res[m][x]["Total"][3]
            e = p * t_s
            print(f"{m:3s} {x:6s} {p * 1e3:6.2f} mW  {e * 1e9:7.1f} nJ  {e / macs * 1e12:6.2f} pJ/MAC  "
                  f"{2 * macs / t_s / p / 1e9:6.1f} GOPS/W (2 ops/MAC)  "
                  f"above-idle {(p - idle) * t_s / macs * 1e12:5.2f} pJ/MAC")

    print("\n## Per-function breakdown (mW, total power; SDF-timed)")
    labels = ["clock gates (ICG dlclkp)"] + [g[0] for g in GROUPS] + ["other"]
    table = {}
    counts = {}
    for x in ("idle", "dense", "sparse", "drain1"):
        acc = {l: 0.0 for l in labels}
        cnt = {l: 0 for l in labels}
        # OpenSTA writes escaped instance names with a raw backslash (invalid JSON escape)
        txt = open(pdir / "sdf" / f"{x}_inst.json").read().replace("\\", "\\\\")
        for r in json.loads(txt):
            g = group_of(r["name"])
            acc[g] += r["total"]
            cnt[g] += 1
        table[x] = acc
        counts = cnt
        tot = sum(acc.values())
        rpt = res["sdf"][x]["Total"][3]
        print(f"# {x}: sum of instances {tot * 1e3:.3f} mW vs report_power {rpt * 1e3:.3f} mW")
    print(f"{'group':34s} {'cells':>6s} " + " ".join(f"{x:>9s}" for x in table) + "   dense %")
    for l in labels:
        print(f"{l:34s} {counts[l]:6d} " + " ".join(f"{table[x][l] * 1e3:9.3f}" for x in table)
              + f"   {table['dense'][l] / sum(table['dense'].values()) * 100:5.1f}%")


if __name__ == "__main__":
    if len(sys.argv) > 3:
        ICGS.update(m.group(1) for m in re.finditer(r"sky130_fd_sc_hd__dlclkp_\d+\s+(\S+)", open(sys.argv[3]).read()))
    main(*sys.argv[1:3])
