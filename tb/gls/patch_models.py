#!/usr/bin/env python3
"""Make the sky130 *timing* cell models usable in Icarus Verilog.

In the timing models, internal wires like D_delayed / CLK_delayed are driven only
by the delayed-signal outputs of $setuphold/$recrem (negative timing checks).
Icarus ignores timing checks, so those wires stay undriven and every flop gives X.
This writes a copy of the models with `assign X_delayed = X;` added after each
`wire X_delayed;` declaration (zero extra delay; SDF IOPATH delays still apply).
Usage: patch_models.py <sky130_fd_sc_hd.v> <out.v>
"""
import re
import sys

src, dst = sys.argv[1], sys.argv[2]
n = 0
out = []
for line in open(src):
    out.append(line)
    m = re.match(r"\s*wire\s+(\w+)_delayed\s*;", line)
    if m:
        out.append(f"    assign {m.group(1)}_delayed = {m.group(1)};  // added for Icarus GLS\n")
        n += 1
open(dst, "w").write("".join(out))
print(f"added {n} assigns -> {dst}")
