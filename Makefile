# Top-level convenience targets. Works without activating the venv.
#   make lint          Verilator -Wall lint of all RTL
#   make test-model    golden-model self-checks (pytest)
#   make test-pe       PE cocotb tests (SIM=verilator default, or SIM=icarus)
#   make test          all of the above
#   make smoke         Milestone 0 toolchain smoke test
#   make clean
SIM ?= verilator
VERILATOR_BIN ?= $(HOME)/tools/verilator/5.052/bin
export PATH := $(CURDIR)/.venv/bin:$(VERILATOR_BIN):$(PATH)

RTL := rtl/pe.sv

.PHONY: lint test-model test-pe test smoke clean
lint:
	verilator --lint-only -Wall $(RTL)

test-model:
	python -m pytest -q model

test-pe:
	$(MAKE) -C tb/pe SIM=$(SIM)

test: lint test-model test-pe

smoke:
	$(MAKE) -C tb/smoke SIM=$(SIM)

clean:
	-$(MAKE) -C tb/pe clean
	-$(MAKE) -C tb/smoke clean
	rm -rf .pytest_cache model/__pycache__ tb/*/__pycache__
