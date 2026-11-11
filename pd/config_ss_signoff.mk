# ORFS design config: config_ss.mk (optimize at ss_100C_1v60) + signoff margins in the SDC.
# Run: make -C ~/OpenROAD-flow-scripts/flow DESIGN_CONFIG=$HOME/systolic-array/pd/config_ss_signoff.mk \
#        WORK_HOME=$HOME/systolic-array/build/orfs NUM_CORES=8 FLOW_VARIANT=ss_clk10_signoff <stage>
# First used for EXP-013 (2026-11-11).
include $(dir $(DESIGN_CONFIG))config_ss.mk
export SDC_FILE = $(PD_DIR)constraint_clk10_ss_signoff.sdc
