# power_chart.py: docs/images/power_clock_gating.png from the numbers in build/power/{exp032,exp033holdeco_r3}/summary.txt.
# Usage (repo root): python3 docs/scripts/power_chart.py
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
SURF, INK, INK2, GRID = "#fcfcfb", "#0b0b0b", "#52514e", "#e4e3df"
S1, S2 = "#2a78d6", "#eb6834"
work = ["Idle (clock running, no jobs)", "Dense matmul", "Sparse matmul (A, B 50% zeros)", "Drain (output phase)"]
base = [40.27, 87.40, 61.60, 68.15]   # build/power/exp032/summary.txt (tt, SDF)
gate = [5.36, 80.65, 55.30, 50.47]    # build/power/exp033holdeco_r3/summary.txt (final layout)
fig, ax = plt.subplots(figsize=(8, 4.2), dpi=150)
fig.patch.set_facecolor(SURF); ax.set_facecolor(SURF)
h = 0.36; gap = 0.02
ys = list(range(len(work)))[::-1]
for y, b, g in zip(ys, base, gate):
    ax.barh(y + h/2 + gap/2, b, height=h, color=S1, edgecolor=SURF, linewidth=0)
    ax.barh(y - h/2 - gap/2, g, height=h, color=S2, edgecolor=SURF, linewidth=0)
    ax.text(b + 1, y + h/2 + gap/2, f"{b:.1f}", va="center", fontsize=8, color=INK2)
    pct = (g - b) / b * 100
    ax.text(g + 1, y - h/2 - gap/2, f"{g:.1f}  ({pct:+.0f}%)", va="center", fontsize=8, color=INK)
ax.set_yticks(ys); ax.set_yticklabels(work, fontsize=9, color=INK)
ax.set_xlabel("Total power (mW), tt corner, 100 MHz, SDF-timed gate-level activity", fontsize=8, color=INK2)
ax.set_xlim(0, 100)
ax.xaxis.grid(True, color=GRID, lw=0.8); ax.set_axisbelow(True)
for s in ("top", "right", "left"): ax.spines[s].set_visible(False)
ax.spines["bottom"].set_color(GRID)
ax.tick_params(axis="x", colors=INK2, labelsize=8); ax.tick_params(axis="y", length=0)
from matplotlib.patches import Patch
ax.legend(handles=[Patch(color=S1, label="No clock gating (EXP-032)"), Patch(color=S2, label="Clock gating, final layout (EXP-033-ECO)")],
          loc="lower left", bbox_to_anchor=(0, 1.0), ncol=2, frameon=False, fontsize=8, labelcolor=INK)
ax.set_title("Clock gating: power per workload", fontsize=11, color=INK, loc="left", pad=26)
fig.savefig("docs/images/power_clock_gating.png", facecolor=SURF, bbox_inches="tight")
