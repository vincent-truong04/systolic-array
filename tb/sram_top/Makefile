# systolic_sram_top tests (D-018).  make [N=8] [PIPE_MAC=0|1] [GATE_DATA=0|1] [WAVES=1]
# Uses the behavioral SRAM model tb/models/sky130_sram_1rw1r_80x64_8.sv (simulation only).
SIM ?= verilator
TOPLEVEL_LANG = verilog
N ?= 8
export N
PIPE_MAC ?= 1
export PIPE_MAC
GATE_DATA ?= 1
export GATE_DATA

REPO := $(abspath $(CURDIR)/../..)
VERILOG_SOURCES = $(REPO)/rtl/pe.sv $(REPO)/rtl/skew.sv $(REPO)/rtl/pe_array.sv $(REPO)/rtl/systolic_top.sv \
                  $(REPO)/rtl/systolic_sram_top.sv $(REPO)/tb/models/sky130_sram_1rw1r_80x64_8.sv
COCOTB_TOPLEVEL = systolic_sram_top
COCOTB_TEST_MODULES = test_sram_top
SIM_BUILD = sim_build_$(SIM)_N$(N)_P$(PIPE_MAC)_G$(GATE_DATA)
export PYTHONPATH := $(REPO)/model:$(PYTHONPATH)

ifeq ($(SIM),verilator)
EXTRA_ARGS += -Wall -GN=$(N) -GPIPE_MAC=$(PIPE_MAC) -GGATE_DATA=$(GATE_DATA)
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
