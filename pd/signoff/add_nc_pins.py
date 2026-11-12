#!/usr/bin/env python3
"""Make unconnected std-cell pins explicit for Netgen LVS: OpenROAD write_verilog omits unconnected pins
(e.g. CTS clkload* dummy-load outputs), while Magic extraction gives each floating output its own net.
Adds .PIN(nc_<k>) with a fresh one-pin wire for every pin in the cell's .subckt that the instance omits.
Usage: add_nc_pins.py in.v cells.spice out.v"""
import re, sys
vin, spice, vout = sys.argv[1:4]
pins = {}
for line in open(spice):
    if line.lower().startswith(".subckt"):
        t = line.split(); pins[t[1]] = t[2:]
src = open(vin).read()
inst_re = re.compile(r"^(\s*)(sky130_\w+)\s+(\S+)\s*\((.*?)\);", re.S | re.M)
k = 0; added = {}; unknown = set()
def fix(m):
    global k
    ind, cell, name, body = m.groups()
    if cell not in pins:
        unknown.add(cell); return m.group(0)
    have = set(re.findall(r"\.(\w+)\s*\(", body))
    extra = []
    for p in pins[cell]:
        if p not in have:
            extra.append(f".{p}(nc_{k})"); added[cell] = added.get(cell, 0) + 1; k += 1
    if not extra: return m.group(0)
    return f"{ind}{cell} {name} ({body.rstrip()},\n    " + ",\n    ".join(extra) + ");"
out = inst_re.sub(fix, src)
wires = "".join(f" wire nc_{i};\n" for i in range(k))
out, n = re.subn(r"(\n\s*wire\s)", "\n" + wires.rstrip("\n") + r"\1", out, count=1)
if n != 1: sys.exit("could not find a wire declaration to insert before")
open(vout, "w").write(out)
print(f"added {k} nc pins; per cell: {sorted(added.items(), key=lambda x: -x[1])[:12]}")
if unknown: print("cells without .subckt (left as is):", sorted(unknown))
