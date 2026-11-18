# block_diagram.py: docs/images/block_diagram.png (README overview diagram of systolic_top).
# Usage (repo root): python3 docs/scripts/block_diagram.py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

SURF, INK, INK2, LINE = "#fcfcfb", "#0b0b0b", "#52514e", "#8a8984"
PE_FILL, PE_EDGE, BOX_FILL = "#e3eefb", "#2a78d6", "#f1f0ec"

fig, ax = plt.subplots(figsize=(8.4, 6.4), dpi=150)
fig.patch.set_facecolor(SURF); ax.set_facecolor(SURF)
ax.set_xlim(0, 12); ax.set_ylim(-1.2, 8); ax.axis("off")

def box(x, y, w, h, text, fc=BOX_FILL, ec=LINE, fs=9, bold=False):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.12",
                                fc=fc, ec=ec, lw=1.0))
    ax.text(x + w/2, y + h/2, text, ha="center", va="center", fontsize=fs, color=INK,
            fontweight="bold" if bold else "normal")

def arrow(x0, y0, x1, y1):
    ax.annotate("", xy=(x1, y1), xytext=(x0, y0),
                arrowprops=dict(arrowstyle="-|>", color=LINE, lw=1.2, shrinkA=0, shrinkB=0))

# PE grid (shown as 4x4 of the 8x8)
gx, gy, cell, n = 4.6, 1.5, 0.95, 4
for i in range(n):
    for j in range(n):
        x, y = gx + j*cell, gy + (n-1-i)*cell
        ax.add_patch(FancyBboxPatch((x+0.08, y+0.08), cell-0.16, cell-0.16,
                     boxstyle="round,pad=0,rounding_size=0.08", fc=PE_FILL, ec=PE_EDGE, lw=1.0))
        ax.text(x+cell/2, y+cell/2, "PE", ha="center", va="center", fontsize=7, color=INK2)
        if j < n-1: arrow(x+cell-0.1, y+cell/2, x+cell+0.1, y+cell/2)
        if i < n-1: arrow(x+cell/2, y+0.1, x+cell/2, y-0.1)
ax.text(gx + n*cell + 0.35, gy + n*cell/2, "8 × 8 PE array\n(4 × 4 shown)\n\neach PE:\nacc += a × b\nINT8 × INT8 → INT32",
        ha="left", va="center", fontsize=8.5, color=INK)

# A input + skew (left)
box(0.2, 3.0, 1.7, 1.0, "A in\n8 × INT8\nper cycle")
box(2.3, 2.6, 1.8, 1.8, "skew\nrow i delayed\ni cycles")
arrow(1.9, 3.5, 2.3, 3.5)
for i in range(n):
    y = gy + (n-1-i)*cell + cell/2
    arrow(4.1, 3.5 + (y-3.5)*0.0, gx+0.08, y) if False else ax.annotate("", xy=(gx+0.08, y), xytext=(4.1, 2.75 + i*0.0 + (3-i)*0.43),
        arrowprops=dict(arrowstyle="-|>", color=LINE, lw=1.0, connectionstyle="arc3,rad=0"))
ax.text(1.05, 2.75, "activations\nflow right →", ha="center", va="top", fontsize=8, color=INK2)

# B input + skew (top)
box(gx + 0.3, 7.0, 3.2, 0.75, "B in: 8 × INT8 per cycle")
box(gx + 0.25, 5.75, 3.3, 0.8, "skew: column j delayed j cycles")
arrow(gx + 1.9, 7.0, gx + 1.9, 6.55)
for j in range(n):
    x = gx + j*cell + cell/2
    arrow(x, 5.75, x, gy + n*cell - 0.08)
ax.text(gx + n*cell + 0.25, 6.15, "weights\nflow down ↓", ha="left", va="center", fontsize=8, color=INK2)

# Output (below)
box(gx + 0.25, -1.05, 3.3, 0.85, "C out: 1 row per cycle, 8 × INT32")
for j in range(n):
    x = gx + j*cell + cell/2
    arrow(x, gy + 0.08, x, -0.2)
ax.text(gx + n*cell + 0.35, -0.2, "after the last term, the sums\nshift down the columns and out", ha="left", va="center", fontsize=8, color=INK2)

ax.text(0.2, 7.75, "systolic_top", fontsize=11, color=INK, fontweight="bold", va="top")
ax.text(0.2, 7.3, "C (8×8) = A (8×K) · B (K×8)", fontsize=9, color=INK2, va="top")
fig.savefig("docs/images/block_diagram.png", facecolor=SURF, bbox_inches="tight")
