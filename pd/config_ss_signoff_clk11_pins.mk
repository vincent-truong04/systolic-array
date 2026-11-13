# EXP-015: EXP-014 (ss-optimized, signoff margins, 11 ns) + dataflow pin placement. One variable: IO_CONSTRAINTS.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11.mk
export IO_CONSTRAINTS = $(PD_DIR)io_dataflow.tcl
