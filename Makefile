# Top-level convenience targets. Works without activating the venv.
#   make lint          Verilator -Wall lint of all RTL
#   make test-model    golden-model self-checks (pytest)
#   make test-pe       PE cocotb tests (SIM=verilator default, or SIM=icarus)
#   make test-skew     skew tests over several (LANES, W, HAS_RESET) sets
#   make test-top      systolic_top tests for N in TOP_NS (default 1 2 4 8)
#   make test          all of the above
#   make smoke         Milestone 0 toolchain smoke test
#   make clean
SIM ?= verilator
VERILATOR_BIN ?= $(HOME)/tools/verilator/5.052/bin
export PATH := $(CURDIR)/.venv/bin:$(VERILATOR_BIN):$(PATH)

RTL := rtl/pe.sv rtl/skew.sv rtl/pe_array.sv rtl/systolic_top.sv
SKEW_CFGS := 1,8,0 4,8,0 4,2,1 8,8,0 8,2,1
TOP_NS := 1 2 4 8

.PHONY: lint test-model test-pe test-skew test-top test smoke clean
# Leaf modules are linted alone; the full hierarchy is linted from systolic_top per N.
lint:
	@for f in rtl/pe.sv rtl/skew.sv; do echo "lint $$f"; verilator --lint-only -Wall $$f || exit 1; done
	@for n in $(TOP_NS); do echo "lint systolic_top N=$$n"; \
	  verilator --lint-only -Wall -GN=$$n --top-module systolic_top $(RTL) || exit 1; done

test-model:
	python -m pytest -q model

test-pe:
	$(MAKE) -C tb/pe SIM=$(SIM)

test-skew:
	@set -e; for c in $(SKEW_CFGS); do set -- $$(echo $$c | tr , ' '); \
	  echo "== skew LANES=$$1 W=$$2 HAS_RESET=$$3"; \
	  $(MAKE) -s -C tb/skew SIM=$(SIM) LANES=$$1 W=$$2 HAS_RESET=$$3 | grep -E 'TESTS=|FAIL'; done

test-top:
	@set -e; for n in $(TOP_NS); do echo "== systolic_top N=$$n"; \
	  $(MAKE) -s -C tb/top SIM=$(SIM) N=$$n | grep -E 'TESTS=|FAIL'; done

test: lint test-model test-pe test-skew test-top

smoke:
	$(MAKE) -C tb/smoke SIM=$(SIM)

clean:
	-$(MAKE) -C tb/pe clean
	-$(MAKE) -C tb/smoke clean
	rm -rf .pytest_cache model/__pycache__ tb/*/__pycache__
