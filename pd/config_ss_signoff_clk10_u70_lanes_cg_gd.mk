# EXP-033: EXP-032 + D-017 data-register enables (one variable: GATE_DATA=1), so a_out/b_out/
# prod_q, a_q/b_q and out_row/out_data also get clock gates.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk10_u70_lanes_cg.mk
export VERILOG_TOP_PARAMS = N 8 PIPE_MAC 1 GATE_DATA 1
