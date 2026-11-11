# systolic_top tests.  make N=4 [PIPE_MAC=0|1] [SIM=icarus] [WAVES=1]
SIM ?= verilator
TOPLEVEL_LANG = verilog
N ?= 4
export N
PIPE_MAC ?= 1
export PIPE_MAC

REPO := $(abspath $(CURDIR)/../..)
VERILOG_SOURCES = $(REPO)/rtl/pe.sv $(REPO)/rtl/skew.sv $(REPO)/rtl/pe_array.sv $(REPO)/rtl/systolic_top.sv
COCOTB_TOPLEVEL = systolic_top
COCOTB_TEST_MODULES = test_top
SIM_BUILD = sim_build_$(SIM)_N$(N)_P$(PIPE_MAC)
export PYTHONPATH := $(REPO)/model:$(PYTHONPATH)

ifeq ($(SIM),icarus)
COMPILE_ARGS += -g2012 -Psystolic_top.N=$(N) -Psystolic_top.PIPE_MAC=$(PIPE_MAC)
endif
ifeq ($(SIM),verilator)
EXTRA_ARGS += -Wall -GN=$(N) -GPIPE_MAC=$(PIPE_MAC)
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
