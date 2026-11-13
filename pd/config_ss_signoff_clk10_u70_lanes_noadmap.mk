# EXP-027: EXP-025 with ADDER_MAP_FILE empty: no extract_fa/techmap to fa_1/ha_1; ABC maps adders.
# (platform config uses ?=, so an empty definition here wins.)
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk10_u70_lanes.mk
export ADDER_MAP_FILE =
