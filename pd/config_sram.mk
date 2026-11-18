# EXP-035 (DRAFT, Milestone 5, D-018): systolic_sram_top = EXP-033 core settings + weight buffer
# macro sky130_sram_1rw1r_80x64_8 (OpenRAM, 758.67 x 239.855 um).
# Everything not listed here is inherited from the final-layout chain (EXP-033: 10 ns ss signoff
# SDC margins, INFER_CLKGATES, GATE_DATA 1, PLACE_DENSITY 0.80, SETUP_SLACK_MARGIN 0.6, operand-flop
# upsizing, antenna iter 10).
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk10_u70_lanes_cg_gd.mk

export DESIGN_NAME     = systolic_sram_top
export DESIGN_NICKNAME = systolic_8x8_sram
export VERILOG_FILES   = $(RTL_DIR)/pe.sv $(RTL_DIR)/skew.sv $(RTL_DIR)/pe_array.sv \
                         $(RTL_DIR)/systolic_top.sv $(RTL_DIR)/systolic_sram_top.sv
export SDC_FILE        = $(PD_DIR)constraint_sram_clk10.sdc

# --- the macro: abstract (LEF), timing (LIB, TT only, OpenRAM analytical model) and layout (GDS) ---
# "=" (expanded late): PLATFORM_HOME is defined by ORFS after this file is read.
SRAM_DIR = $(PLATFORM_HOME)/sky130ram/sky130_sram_1rw1r_80x64_8
export ADDITIONAL_LEFS = $(SRAM_DIR)/sky130_sram_1rw1r_80x64_8.lef
# Project copy of the .lib with the bus direction fixed ([79:0] like the Verilog/LEF; the ORFS copy
# declares [0:79], which made OpenROAD bit-reverse every macro bus: first EXP-035 placement).
export ADDITIONAL_LIBS = $(PD_DIR)macros/sky130_sram_1rw1r_80x64_8_TT_1p8V_25C.lib
export ADDITIONAL_GDS  = $(SRAM_DIR)/sky130_sram_1rw1r_80x64_8.gds

# --- floorplan: explicit die/core instead of utilization (the macro is wider than EXP-033's core) ---
# Core 787.04 x 924.80 um (1711 sites x 340 rows). Macro on top, mirrored (MX) so its read port
# (dout1, 26 um from its lower edge after MX) faces the array and its write port (din0) faces the
# top die edge, where the wr_* pins go. Stdcell region below the macro halo: 787 x 664 um
# (~EXP-033's 517,276 um2 core, so ~70% utilization again).
export CORE_UTILIZATION =
export DIE_AREA  = 0 0 789.80 930.24
export CORE_AREA = 1.38 2.72 788.42 927.52
# Shared by macro_place_sram.tcl, tapcell_sram.tcl and io_sram.tcl (one source of truth):
export SRAM_X    = 15.64
# SRAM_Y: tried 655.52 (variant fp2: 8 rows of free strip above the macro for the write regs).
# Global placement also pulled u_core.b_q (dout1's capture flops) into that strip, across the macro
# from dout1 and the array: setup WNS -0.79 / TNS -9.75 vs -0.33 / -2.20 at 677.28 (fp3). Kept
# 677.28: the write path crosses the macro twice, but it is a full-cycle path (+6.96 ns at place).
export SRAM_Y    = 677.28
export SRAM_HALO = 10
export MACRO_PLACEMENT_TCL = $(PD_DIR)macro_place_sram.tcl
export TAPCELL_TCL         = $(PD_DIR)tapcell_sram.tcl
export PDN_TCL             = $(PD_DIR)pdn_sram.tcl
export IO_CONSTRAINTS      = $(PD_DIR)io_sram.tcl
# rtl_macro_placer checks macro + half a minimum channel per side against the core, even for a
# fixed macro. The platform default RTLMP_MIN_CHANNEL_SIZE 80 80 (= 40 um per side) made the
# 758.67 um macro 838.67 um wide > 786.6 um core (MPL-0006, first EXP-035 floorplan). 20 20 =
# 10 um per side, same as SRAM_HALO.
export RTLMP_MIN_CHANNEL_SIZE = 20 20
