# systolic_top tests.  make N=4 [PIPE_MAC=0|1] [GATE_DATA=0|1] [SIM=icarus] [WAVES=1]
SIM ?= verilator
TOPLEVEL_LANG = verilog
N ?= 4
export N
PIPE_MAC ?= 1
export PIPE_MAC
GATE_DATA ?= 0
export GATE_DATA

REPO := $(abspath $(CURDIR)/../..)
VERILOG_SOURCES = $(REPO)/rtl/pe.sv $(REPO)/rtl/skew.sv $(REPO)/rtl/pe_array.sv $(REPO)/rtl/systolic_top.sv
COCOTB_TOPLEVEL = systolic_top
COCOTB_TEST_MODULES = test_top
SIM_BUILD = sim_build_$(SIM)_N$(N)_P$(PIPE_MAC)$(if $(filter 1,$(GATE_DATA)),_G1)
export PYTHONPATH := $(REPO)/model:$(PYTHONPATH)

ifeq ($(SIM),icarus)
COMPILE_ARGS += -g2012 -Psystolic_top.N=$(N) -Psystolic_top.PIPE_MAC=$(PIPE_MAC) -Psystolic_top.GATE_DATA=$(GATE_DATA)
endif
ifeq ($(SIM),verilator)
EXTRA_ARGS += -Wall -GN=$(N) -GPIPE_MAC=$(PIPE_MAC) -GGATE_DATA=$(GATE_DATA)
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
