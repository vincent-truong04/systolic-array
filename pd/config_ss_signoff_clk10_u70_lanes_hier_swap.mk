# EXP-030: EXP-029 + SWAP_ARITH_OPERATORS=1 (Yosys builds prefix-adder/Booth alternatives,
# OpenROAD replace_arith_modules swaps them on critical paths at floorplan). No RTL change.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk10_u70_lanes_hier.mk
export SWAP_ARITH_OPERATORS = 1
