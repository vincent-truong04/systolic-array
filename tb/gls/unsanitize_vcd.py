#!/usr/bin/env python3
"""Undo sanitize_names.py in a VCD from an SDF gate-level run, so OpenROAD's read_vcd
matches the nets of 6_final.odb. Rewrites only the header ($var references):
esc_<plain> -> \\<original escaped name>, the form Icarus writes for escaped
identifiers in a zero-delay run. Usage:
    unsanitize_vcd.py <original 6_final.v> in.vcd out.vcd
"""
import re
import sys

from sanitize_names import plain


def main(vorig, vin, vout):
    raw_names = set(re.findall(r"\\(\S+)(?=\s)", open(vorig).read()))
    back = {plain(r): r for r in raw_names}
    var = re.compile(r"^(\s*\$var\s+\S+\s+\d+\s+\S+\s+)(\S+)(.*)$")
    n_var = n_ren = 0
    with open(vin) as fi, open(vout, "w") as fo:
        for line in fi:
            m = var.match(line)
            if m:
                n_var += 1
                ref = m.group(2)
                if ref in back:
                    line = f"{m.group(1)}\\{back[ref]}{m.group(3)}\n"
                    n_ren += 1
            fo.write(line)
            if line.startswith("$enddefinitions"):
                break
        while True:                      # value changes: copy in big chunks
            buf = fi.read(1 << 24)
            if not buf:
                break
            fo.write(buf)
    print(f"$var lines: {n_var}; renamed esc_* -> escaped: {n_ren}; mapping size {len(back)}")


if __name__ == "__main__":
    main(*sys.argv[1:4])
