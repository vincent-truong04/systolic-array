# EXP-016: EXP-015 (dataflow pins) + more post-route antenna repair iterations (default 5).
# EXP-015 stopped at the 5-iteration limit with 2 violations left (37 -> 8 -> 8 -> 3 -> 2).
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11_pins.mk
export MAX_REPAIR_ANTENNAS_ITER_DRT = 10
