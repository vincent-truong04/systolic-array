# EXP-025: EXP-024 at 10.0 ns (one variable: clock period). Baseline for EXP-026..028.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11_u70_lanes.mk
export SDC_FILE = $(dir $(DESIGN_CONFIG))constraint_clk10_ss_signoff.sdc
