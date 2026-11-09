# PE unit tests.  From repo root:  make test-pe [SIM=icarus]
# Waveforms: add WAVES=1 (Verilator -> sim_build/*.fst, Icarus -> sim_build/*.fst)
SIM ?= verilator
TOPLEVEL_LANG = verilog

REPO := $(abspath $(CURDIR)/../..)
VERILOG_SOURCES = $(REPO)/rtl/pe.sv
COCOTB_TOPLEVEL = pe
COCOTB_TEST_MODULES = test_pe
export PYTHONPATH := $(REPO)/model:$(PYTHONPATH)

ifeq ($(SIM),icarus)
COMPILE_ARGS += -g2012
endif
ifeq ($(SIM),verilator)
EXTRA_ARGS += -Wall
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
