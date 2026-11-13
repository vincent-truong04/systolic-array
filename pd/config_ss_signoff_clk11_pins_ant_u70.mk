# EXP-021: EXP-016 (dataflow pins + antenna iter 10) + utilization 50 -> 70.
# PLACE_DENSITY 0.80 with it (same pairing as EXP-007). No padding, no setup margin (point between EXP-017 60% and EXP-018 75%).
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11_pins_ant.mk
export CORE_UTILIZATION = 70
export PLACE_DENSITY    = 0.80
