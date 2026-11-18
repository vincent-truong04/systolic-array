# pe_placement.py: docs/images/pe_placement.png. Usage: python3 docs/scripts/pe_placement.py insts.tsv docs/images/pe_placement.png
# (insts.tsv from export_insts.tcl). Flip-flops named u_array.g_row[i].g_col[j]... are colored per PE (checkerboard).
import re, sys, statistics as st
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
src, out = sys.argv[1], sys.argv[2]
SURF, INK, INK2, MUTED = "#fcfcfb", "#0b0b0b", "#52514e", "#bdbbb5"
C_EVEN, C_ODD = "#2a78d6", "#eb6834"
die = None; other = []; pe = {}
for line in open(src):
    if line.startswith("#die"):
        _, x, y = line.split(); die = (int(x)/1000, int(y)/1000); continue
    n, m, x0, y0, x1, y1 = line.rstrip("\n").split("\t")
    cx, cy = (int(x0)+int(x1))/2000, (int(y0)+int(y1))/2000
    mm = re.search(r"u_array\.g_row\\?\[(\d)\\?\]\.g_col\\?\[(\d)\\?\]", n)
    if mm and "dfxtp" in m:
        pe.setdefault((int(mm[1]), int(mm[2])), []).append((cx, cy))
    else:
        other.append((cx, cy))
fig, ax = plt.subplots(figsize=(7.2, 7.6), dpi=150)
fig.patch.set_facecolor(SURF); ax.set_facecolor(SURF)
ax.add_patch(Rectangle((0, 0), die[0], die[1], fill=False, ec=INK2, lw=0.8))
ax.scatter([p[0] for p in other], [p[1] for p in other], s=0.6, c=MUTED, lw=0, rasterized=True)
for (i, j), pts in pe.items():
    col = C_EVEN if (i + j) % 2 == 0 else C_ODD
    ax.scatter([p[0] for p in pts], [p[1] for p in pts], s=2.2, c=col, lw=0, rasterized=True)
    mx, my = st.median(p[0] for p in pts), st.median(p[1] for p in pts)
    ax.text(mx, my, f"{i},{j}", ha="center", va="center", fontsize=7, color=INK,
            bbox=dict(boxstyle="round,pad=0.15", fc=SURF, ec="none", alpha=0.85))
ax.set_xlim(-40, die[0] + 10); ax.set_ylim(-45, die[1] + 45); ax.set_aspect("equal")
for s in ax.spines.values(): s.set_visible(False)
ax.tick_params(colors=INK2, labelsize=7, length=2)
ax.set_xlabel("x (µm)", color=INK2, fontsize=8); ax.set_ylabel("y (µm)", color=INK2, fontsize=8)
ax.annotate("A in (rows) →", (-8, die[1]*0.5), rotation=90, ha="right", va="center", fontsize=8, color=INK2)
ax.text(die[0]*0.5, die[1] + 18, "B in (columns) ↓", ha="center", fontsize=8, color=INK2)
ax.text(die[0]*0.5, -32, "C out (columns) ↓", ha="center", fontsize=8, color=INK2)
ax.set_title("Final placement: registers of PE(row, col), 722.8 × 722.8 µm die", fontsize=10, color=INK, loc="left")
fig.text(0.125, 0.035, "Colored: flip-flops of each PE (alternating colors only to separate neighbors). Gray: all other cells.",
         fontsize=7, color=INK2)
fig.savefig(out, facecolor=SURF, bbox_inches="tight")
print("PEs:", len(pe), "PE flops:", sum(len(v) for v in pe.values()), "other cells:", len(other))
