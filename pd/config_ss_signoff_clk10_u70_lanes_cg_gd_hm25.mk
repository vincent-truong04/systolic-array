# EXP-034: EXP-033 (D-017 GATE_DATA 1 + INFER_CLKGATES) + HOLD_SLACK_MARGIN 0 -> 0.25 ns.
# ORFS repairs hold at ss only; the gated capture clock costs 0.14-0.20 ns more hold at ff than at ss
# on the edge-PE a_out/b_out paths (EXP-033: ff -0.031, 20 endpoints). 0.25 at ss -> ~+0.05 at ff.
# floorplan.tcl uses min(margin, 0), so floorplan/place are identical to EXP-033: rerun from CTS.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk10_u70_lanes_cg_gd.mk
export HOLD_SLACK_MARGIN = 0.25
