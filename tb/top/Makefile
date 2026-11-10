# systolic_top tests.  make N=4 [SIM=icarus] [WAVES=1]
SIM ?= verilator
TOPLEVEL_LANG = verilog
N ?= 4
export N

REPO := $(abspath $(CURDIR)/../..)
VERILOG_SOURCES = $(REPO)/rtl/pe.sv $(REPO)/rtl/skew.sv $(REPO)/rtl/pe_array.sv $(REPO)/rtl/systolic_top.sv
COCOTB_TOPLEVEL = systolic_top
COCOTB_TEST_MODULES = test_top
SIM_BUILD = sim_build_$(SIM)_N$(N)
export PYTHONPATH := $(REPO)/model:$(PYTHONPATH)

ifeq ($(SIM),icarus)
COMPILE_ARGS += -g2012 -Psystolic_top.N=$(N)
endif
ifeq ($(SIM),verilator)
EXTRA_ARGS += -Wall -GN=$(N)
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
