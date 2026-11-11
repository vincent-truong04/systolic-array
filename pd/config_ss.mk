# ORFS design config: same as config.mk, but optimize against the slow corner.
# Run (from anywhere):
#   make -C ~/OpenROAD-flow-scripts/flow DESIGN_CONFIG=$HOME/systolic-array/pd/config_ss.mk \
#        WORK_HOME=$HOME/systolic-array/build/orfs NUM_CORES=8 FLOW_VARIANT=ss_clk10 <stage>
# First used for EXP-012 (2026-11-11).
include $(dir $(DESIGN_CONFIG))config.mk

# Single-corner flow at ss_100C_1v60 (100 C, 1.60 V) instead of the platform's tt_025C_1v80.
# The sky130hd platform config uses LIB_FILES ?=, so this takes precedence.
# Source + sha256 of the lib: ~/pdk-libs/sky130_fd_sc_hd/SOURCE.txt
export LIB_FILES          = $(HOME)/pdk-libs/sky130_fd_sc_hd/sky130_fd_sc_hd__ss_100C_1v60.lib
export VERILOG_TOP_PARAMS = N 8 PIPE_MAC 1
export SDC_FILE           = $(PD_DIR)constraint_clk10_ss.sdc
