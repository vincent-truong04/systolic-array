# EXP-023: EXP-022 (util 70, PLACE_DENSITY 0.80, SETUP_SLACK_MARGIN 0.6) + operand-flop upsizing before CTS.
# pd/upsize_operand_flops.tcl: dfxtp_1/2 with Q fanout >= 8 -> dfxtp_4 (see EXP-022 worst path).
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11_pins_ant_u70_ssm06.mk
export PRE_CTS_TCL = $(dir $(DESIGN_CONFIG))upsize_operand_flops.tcl
