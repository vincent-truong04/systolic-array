# EXP-017: EXP-016 + utilization 50 -> 60. PLACE_DENSITY 0.60 -> 0.70 with it (as EXP-006):
# target density must exceed utilization, so the two move together as one "utilization" knob.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11_pins_ant.mk
export CORE_UTILIZATION = 60
export PLACE_DENSITY    = 0.70
