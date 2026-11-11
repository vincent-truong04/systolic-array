# ORFS design config: systolic_top, 8x8, sky130hd
# Run (from anywhere):
#   make -C ~/OpenROAD-flow-scripts/flow DESIGN_CONFIG=$HOME/systolic-array/pd/config.mk \
#        WORK_HOME=$HOME/systolic-array/build/orfs NUM_CORES=8 <stage>
# Baseline (EXP-003) uses platform defaults for all optimization knobs; change one at a time.

# --- Design identity --------------------------------------------------------
export DESIGN_NAME     = systolic_top
export DESIGN_NICKNAME = systolic_8x8
export PLATFORM        = sky130hd

# --- Sources ----------------------------------------------------------------
# This file is include'd from ~/OpenROAD-flow-scripts/flow, so anchor all paths
# to the directory of DESIGN_CONFIG (must be passed as an absolute path).
PD_DIR  := $(dir $(DESIGN_CONFIG))
RTL_DIR := $(PD_DIR)../rtl

export VERILOG_FILES      = $(RTL_DIR)/pe.sv $(RTL_DIR)/skew.sv \
                            $(RTL_DIR)/pe_array.sv $(RTL_DIR)/systolic_top.sv
export VERILOG_TOP_PARAMS = N 8
export SDC_FILE           = $(PD_DIR)constraint.sdc

# --- Floorplan / placement --------------------------------------------------
export CORE_UTILIZATION = 50
export PLACE_DENSITY    = 0.60
