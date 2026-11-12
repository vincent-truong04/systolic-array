# Gate-level simulation of an ORFS final netlist with the top-level cocotb tests.
#   make -C tb/gls NETLIST=<6_final.v>                 zero-delay (FUNCTIONAL models)
#   make -C tb/gls NETLIST=<6_final.v> SDF=<file.sdf>  SDF-annotated delays (Icarus)
# For SDF runs: escaped names must be sanitized first (sanitize_names.py) and the
# timing models patched once (patch_models.py -> build/gls_models/).
# Icarus applies specify-path delays from the SDF; it ignores $setuphold etc.,
# so setup/hold are covered by STA, not by this simulation.
SIM = icarus
TOPLEVEL_LANG = verilog
N ?= 8
export N
PIPE_MAC ?= 1
export PIPE_MAC
export GLS = 1
PDK_ROOT ?= $(HOME)/pdk
MODELS := $(PDK_ROOT)/sky130A/libs.ref/sky130_fd_sc_hd/verilog
REPO := $(abspath $(CURDIR)/../..)
NETLIST ?= $(error set NETLIST=<path to 6_final.v>)
SDF ?=
TAG ?= $(if $(SDF),sdf,func)
SIM_BUILD = sim_build_$(TAG)
COCOTB_RESULTS_FILE = results_$(TAG).xml

COMPILE_ARGS += -g2012
ifeq ($(SDF),)
export EXPECT_DELAY = 0
VERILOG_SOURCES = $(MODELS)/primitives.v $(MODELS)/sky130_fd_sc_hd.v $(abspath $(NETLIST))
COMPILE_ARGS += -DFUNCTIONAL
else
export EXPECT_DELAY = 1
# Timing models patched for Icarus (patch_models.py: drive the *_delayed wires)
PATCHED_MODELS ?= $(REPO)/build/gls_models/sky130_fd_sc_hd_icarus.v
VERILOG_SOURCES = $(MODELS)/primitives.v $(PATCHED_MODELS) $(abspath $(NETLIST))
export SAMPLE_FALL = 1
VERILOG_SOURCES += $(CURDIR)/sdf_annotate.v
COMPILE_ARGS += -gspecify -DSDF_FILE=\"$(abspath $(SDF))\" -s sdf_annotate
endif
COCOTB_TOPLEVEL = systolic_top
COCOTB_TEST_MODULES = test_top,test_gls_delay
export PYTHONPATH := $(REPO)/tb/top:$(REPO)/model:$(PYTHONPATH)

include $(shell cocotb-config --makefiles)/Makefile.sim
