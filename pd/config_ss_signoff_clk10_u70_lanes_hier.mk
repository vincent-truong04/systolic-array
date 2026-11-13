# EXP-029: EXP-025 + OPENROAD_HIERARCHICAL=1 (OpenROAD reads/links the netlist with -hier).
# Control run for EXP-030: SWAP_ARITH_OPERATORS requires this setting.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk10_u70_lanes.mk
export OPENROAD_HIERARCHICAL = 1
