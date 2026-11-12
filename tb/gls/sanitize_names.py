#!/usr/bin/env python3
"""Rename escaped Verilog identifiers (e.g. \\u_array.g_row[0].u_pe.acc[3]$_DFF_P_ )
to plain ones, consistently in a gate netlist and its SDF, because Icarus' SDF
reader cannot match escaped instance names. Usage:
    sanitize_names.py in.v in.sdf out.v out.sdf
"""
import re
import sys

def plain(raw: str) -> str:
    return "esc_" + re.sub(r"[^A-Za-z0-9_]", "_", raw)

def main(vin, sin, vout, sout):
    mapping = {}

    def name_for(raw):
        p = mapping.get(raw)
        if p is None:
            p = plain(raw)
            mapping[raw] = p
        return p

    # Verilog escaped identifier: backslash, then non-whitespace chars, ended by whitespace.
    v = open(vin).read()
    v = re.sub(r"\\(\S+)(?=\s)", lambda m: name_for(m.group(1)), v)
    if len(set(mapping.values())) != len(mapping):
        sys.exit("name collision after sanitizing")
    open(vout, "w").write(v)

    # SDF: identifiers with backslash-escaped chars; an unescaped '.' is the divider.
    sdf_tok = re.compile(r"(?:[A-Za-z0-9_$]|\\.)*\\.(?:[A-Za-z0-9_$]|\\.)*")
    n_sdf = 0
    missing = set()
    def sdf_sub(m):
        nonlocal n_sdf
        raw = re.sub(r"\\(.)", r"\1", m.group(0))
        n_sdf += 1
        if raw not in mapping:
            missing.add(raw)
        return name_for(raw)
    s = sdf_tok.sub(sdf_sub, open(sin).read())
    # OpenSTA writes delay triples as (min::max) with an empty typical value.
    # Icarus annotates the typical value by default, which would make every
    # delay 0, so fill typ with max: (min::max) -> (min:max:max).
    s, n_trip = re.subn(r"\((-?[0-9.eE+-]+)::(-?[0-9.eE+-]+)\)", r"(\1:\2:\2)", s)
    open(sout, "w").write(s)
    print(f"filled typ in {n_trip} delay triples")
    print(f"escaped identifiers in netlist: {len(mapping) - len(missing)}; "
          f"SDF references rewritten: {n_sdf}; SDF names not in netlist: {len(missing)}")
    if missing:
        print("  e.g.", sorted(missing)[:5])

if __name__ == "__main__":
    main(*sys.argv[1:5])
