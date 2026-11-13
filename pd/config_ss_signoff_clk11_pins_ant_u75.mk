# EXP-018: EXP-016 (dataflow pins + antenna iter 10) + utilization 50 -> 75.
# PLACE_DENSITY 0.60 -> 0.85 with it (target density must exceed utilization; EXP-007 used 0.80 at 70).
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11_pins_ant.mk
export CORE_UTILIZATION = 75
export PLACE_DENSITY    = 0.85
