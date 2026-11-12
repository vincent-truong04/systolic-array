# config_ss_signoff.mk at 11 ns (EXP-014). FLOW_VARIANT=ss_clk11_signoff
include $(dir $(DESIGN_CONFIG))config_ss.mk
export SDC_FILE = $(PD_DIR)constraint_clk11_ss_signoff.sdc
