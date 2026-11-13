# EXP-024: EXP-023 (util 70, PLACE_DENSITY 0.80, SETUP_SLACK_MARGIN 0.6, operand-flop upsizing,
# antenna DRT iter 10) with per-lane pin regions instead of the clustered io_dataflow.tcl.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11_pins_ant_u70_ssm06_up.mk
export IO_CONSTRAINTS = $(dir $(DESIGN_CONFIG))io_dataflow_lanes.tcl
