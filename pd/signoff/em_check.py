#!/usr/bin/env python3
"""em_check.py: compare PDNSim per-segment DC currents with sky130 EM limits (2026-11-15, Claude).
Limits: sky130hd tech LEF DCCURRENTDENSITY AVERAGE at Tj = 90 C (mA/um of width for metals,
mA per cut for vias). Widths/cut counts of this design's PDN (6_final.odb special wires):
met1 rail 0.48 um, met2 pad 0.37, met3 pad 0.33, met4/met5 straps 1.6 um; via stacks
met1-met2 5 cuts, met2-met3 4, met3-met4 4, met4-met5 1. Same-layer segments are checked
against width x density; layer-change (via) segments against ONE cut's limit (conservative,
since PDNSim may lump the via array into one resistor).
Usage: em_check.py <em_report.rpt> [...]"""
import csv, sys
DENS = {'met1': 2.8, 'met2': 2.8, 'met3': 6.8, 'met4': 6.8, 'met5': 10.17}      # mA/um
WIDTH = {'met1': 0.48, 'met2': 0.37, 'met3': 0.33, 'met4': 1.6, 'met5': 1.6}     # um
CUT = {('met1', 'met2'): 0.29, ('met2', 'met3'): 0.48, ('met3', 'met4'): 0.48, ('met4', 'met5'): 2.49}
ORDER = ['li1', 'met1', 'met2', 'met3', 'met4', 'met5']
for path in sys.argv[1:]:
    worst = {}
    with open(path) as f:
        r = csv.reader(f); next(r)
        for row in r:
            l0, l1, i_ma = row[0], row[3], abs(float(row[6])) * 1e3
            if l0 == l1:
                key, lim = l0, DENS[l0] * WIDTH[l0]
            else:
                a, b = sorted((l0, l1), key=ORDER.index)
                key, lim = f"{a}-{b}", CUT[(a, b)]
            ratio = i_ma / lim
            if key not in worst or ratio > worst[key][0]:
                worst[key] = (ratio, i_ma, lim, row[1:3])
    print(f"== {path}")
    for k in sorted(worst, key=lambda k: -worst[k][0]):
        ratio, i, lim, xy = worst[k]
        print(f"  {k:10s} max {i:7.3f} mA  limit {lim:6.3f} mA  {100*ratio:5.1f}% of limit  at ({xy[0]}, {xy[1]})")
