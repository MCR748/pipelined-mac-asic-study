PROJECT_DIR := /home/mcrparadox/work/MAC
LIBRELANE_DIR := $(HOME)/librelane

# LibreLane configuration
STAGE := mac_stage1

LL_DESIGNS_DIR := $(LIBRELANE_DIR)/designs
LL_DESIGN_LINK := $(LL_DESIGNS_DIR)/$(STAGE)
PROJECT_DESIGN := $(PROJECT_DIR)/flow/librelane/$(STAGE)

# Simulation configuration (Verilator)
TOP        := mac_top
RTL_DIR    := rtl/mac
TB_DIR     := tb
OBJ_DIR    := obj_dir

VERILATOR  := verilator

VFLAGS := --cc --exe --trace --sv -Wall --x-assign unique --x-initial unique -I$(RTL_DIR)

RTL_SRCS := \
	$(RTL_DIR)/mac_pkg.sv \
	$(RTL_DIR)/mac_top.sv

TB_CPP := $(TB_DIR)/mac_tb.cpp

# Default target
.PHONY: all
all: build

# ---------------- Simulation flow ------------------------

.PHONY: sim
sim: waves

.PHONY: verilate
verilate: .stamp.verilate

.stamp.verilate: $(RTL_SRCS) $(TB_CPP)
	@echo
	@echo "### VERILATING ###"
	$(VERILATOR) $(VFLAGS) \
		$(RTL_SRCS) \
		--top-module $(TOP) \
		--exe $(TB_CPP)
	@touch $@

$(OBJ_DIR)/V$(TOP): .stamp.verilate
	@echo
	@echo "### BUILDING SIM ###"
	$(MAKE) -C $(OBJ_DIR) -f V$(TOP).mk V$(TOP)

.PHONY: build
build: $(OBJ_DIR)/V$(TOP)

waveform.vcd: $(OBJ_DIR)/V$(TOP)
	@echo
	@echo "### SIMULATING ###"
	./$(OBJ_DIR)/V$(TOP)

.PHONY: waves
waves: waveform.vcd
	@echo
	@echo "### WAVES ###"
	gtkwave waveform.vcd

.PHONY: lint
lint:
	$(VERILATOR) --lint-only --sv $(RTL_SRCS)

sim-clean:
	rm -rf $(OBJ_DIR)
	rm -f .stamp.verilate waveform.vcd


# ---------------- LibreLane flow --------------------------
.PHONY: flow
flow:
	cd $(LIBRELANE_DIR) && . $(HOME)/librelane-venv/bin/activate && \
	python3 -m librelane --dockerized --pdk-root $(HOME)/.ciel/ciel $(PROJECT_DIR)/flow/librelane/$(STAGE)/config.json

.PHONY: extract-violations
extract-violations:
	@python3 scripts/extract_violations.py

.PHONY: flow-prune
flow-prune:
	@echo "Pruning LibreLane runs and extracts (keeping latest)..."
	@set -e; \
	RUN_DIR="$(PROJECT_DIR)/flow/librelane/$(STAGE)/runs"; \
	EXT_DIR="$(PROJECT_DIR)/flow/librelane/$(STAGE)/extracts"; \
	\
	if [ -d "$$RUN_DIR" ]; then \
		LATEST_RUN=$$(ls -dt $$RUN_DIR/RUN_* 2>/dev/null | head -n 1); \
		if [ -n "$$LATEST_RUN" ]; then \
			find $$RUN_DIR -mindepth 1 -maxdepth 1 -type d ! -path "$$LATEST_RUN" -exec rm -rf {} +; \
		fi; \
	else \
		echo "No runs directory found."; \
	fi; \
	\
	if [ -d "$$EXT_DIR" ]; then \
		if [ -n "$$LATEST_RUN" ]; then \
			LATEST_NAME=$$(basename $$LATEST_RUN); \
			find $$EXT_DIR -mindepth 1 -maxdepth 1 -type d ! -name "$$LATEST_NAME" -exec rm -rf {} +; \
		fi; \
	else \
		echo "No extracts directory found."; \
	fi


# ----------------------------------------------------------

# Global clean
.PHONY: clean
clean: sim-clean flow-prune
