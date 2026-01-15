PROJECT_DIR   := /mnt/Uni/ASIC/MAC
LIBRELANE_DIR := $(HOME)/librelane

# LibreLane configuration
STAGE := mac_stage0

LL_DESIGNS_DIR := $(LIBRELANE_DIR)/designs
LL_DESIGN_LINK := $(LL_DESIGNS_DIR)/$(STAGE)
PROJECT_DESIGN := $(PROJECT_DIR)/flow/librelane/$(STAGE)

# Simulation configuration (Verilator)
TOP        := mac_top
RTL_DIR    := rtl/mac
TB_DIR     := tb
OBJ_DIR    := obj_dir

VERILATOR  := verilator

VFLAGS := --cc --exe --trace --sv -Wall \
          --x-assign unique --x-initial unique

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

.PHONY: sim-clean
sim-clean:
	rm -rf $(OBJ_DIR)
	rm -f .stamp.verilate waveform.vcd


# ---------------- LibreLane flow --------------------------
.PHONY: flow-link
flow-link:
	@echo "Linking LibreLane design..."
	@if [ ! -L "$(LL_DESIGN_LINK)" ]; then \
		ln -s "$(PROJECT_DESIGN)" "$(LL_DESIGN_LINK)"; \
		echo "Symlink created: $(LL_DESIGN_LINK)"; \
	else \
		echo "Symlink already exists"; \
	fi

.PHONY: flow-mount
flow-mount:
	cd $(LIBRELANE_DIR) && make mount

.PHONY: flow-run
flow-run: flow-link
	cd $(LIBRELANE_DIR) && make mount

# ----------------------------------------------------------
# Global clean
.PHONY: clean
clean: sim-clean
