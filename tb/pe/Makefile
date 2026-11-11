# PE unit tests.  From repo root:  make test-pe [SIM=icarus] [PIPE_MAC=0|1]
# Waveforms: add WAVES=1 (Verilator -> sim_build/*.fst, Icarus -> sim_build/*.fst)
SIM ?= verilator
TOPLEVEL_LANG = verilog
PIPE_MAC ?= 1
export PIPE_MAC
SIM_BUILD = sim_build_$(SIM)_P$(PIPE_MAC)

REPO := $(abspath $(CURDIR)/../..)
VERILOG_SOURCES = $(REPO)/rtl/pe.sv
COCOTB_TOPLEVEL = pe
COCOTB_TEST_MODULES = test_pe
export PYTHONPATH := $(REPO)/model:$(PYTHONPATH)

ifeq ($(SIM),icarus)
COMPILE_ARGS += -g2012 -Ppe.PIPE_MAC=$(PIPE_MAC)
endif
ifeq ($(SIM),verilator)
EXTRA_ARGS += -Wall -GPIPE_MAC=$(PIPE_MAC)
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
