# skew unit test. One parameter set per run; separate build dir per set.
#   make LANES=4 W=8 HAS_RESET=0 [SIM=icarus]
SIM ?= verilator
TOPLEVEL_LANG = verilog
LANES ?= 4
W ?= 8
HAS_RESET ?= 0
export LANES W HAS_RESET

REPO := $(abspath $(CURDIR)/../..)
VERILOG_SOURCES = $(REPO)/rtl/skew.sv
COCOTB_TOPLEVEL = skew
COCOTB_TEST_MODULES = test_skew
SIM_BUILD = sim_build_$(SIM)_L$(LANES)_W$(W)_R$(HAS_RESET)

ifeq ($(SIM),icarus)
COMPILE_ARGS += -g2012 -Pskew.LANES=$(LANES) -Pskew.W=$(W) -Pskew.HAS_RESET=$(HAS_RESET)
endif
ifeq ($(SIM),verilator)
EXTRA_ARGS += -Wall -GLANES=$(LANES) -GW=$(W) -GHAS_RESET=$(HAS_RESET)
endif

include $(shell cocotb-config --makefiles)/Makefile.sim
