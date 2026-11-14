# EXP-031: EXP-025 optimized at the max RC corner (no ECO; one change: wire RC used by optimization).
# LAYER_PARASITICS_FILE: setRC.tcl scaled C x1.10, R x1.14 -> every estimate_parasitics/repair step
# (floorplan, place, CTS, GRT) sees max-corner wires.
# RCX_RULES cannot be overridden here: platforms/sky130hd/config.mk sets it with plain `export =`
# after this file is read (print-RCX_RULES checked 2026-11-13). Final max-RC timing is measured with
# pd/sta/rc_corner_sta.tcl instead, as for EXP-025-ECO.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk10_u70_lanes.mk
export LAYER_PARASITICS_FILE = $(dir $(DESIGN_CONFIG))setRC_rcmax.tcl
