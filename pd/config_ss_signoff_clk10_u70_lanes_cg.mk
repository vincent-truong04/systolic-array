# EXP-032: EXP-025 + clock-gate inference in synthesis (one variable: INFER_CLKGATES).
# Yosys `clockgate` replaces enable-flop groups (today only the PE acc registers) with an
# ICG (sky130_fd_sc_hd__dlclkp) on their clock.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk10_u70_lanes.mk
export INFER_CLKGATES = 1
