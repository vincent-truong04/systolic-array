# Milestone 0 smoke test.  Usage (from repo root, venv active):
#   make -C tb/smoke SIM=verilator     (default)
#   make -C tb/smoke SIM=icarus
SIM ?= verilator
TOPLEVEL_LANG = verilog

VERILOG_SOURCES = $(CURDIR)/smoke_add.sv
COCOTB_TOPLEVEL = smoke_add
COCOTB_TEST_MODULES = test_smoke

ifeq ($(SIM),icarus)
COMPILE_ARGS += -g2012
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
