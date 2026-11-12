#!/usr/bin/env python3
"""Replace Verilog escaped identifiers (\\name<space>) with plain ones (esc_<name with non-word chars -> _>).
Netgen 1.5.133 misparses escaped names containing [ ] $ . (seen 2026-11-12). Usage: in.v out.v"""
import re, sys
src = open(sys.argv[1]).read()
names = {}
def sub(m):
    raw = m.group(1)
    new = names.get(raw)
    if new is None:
        new = "esc_" + re.sub(r"[^A-Za-z0-9_]", "_", raw)
        names[raw] = new
    return new + " "
out = re.sub(r"\\(\S+)\s", sub, src)
if len(set(names.values())) != len(names):
    sys.exit(f"name collision: {len(names)} escaped names -> {len(set(names.values()))} unique")
open(sys.argv[2], "w").write(out)
print(f"{len(names)} escaped identifiers renamed")
