# Copyright 2026 Federico Runco (federico.runco@gmail.com)
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
# 
# Licensed under the Solderpad Hardware License v2.1 (the “License”); 
# you may not use this file except in compliance with the License, or, 
# at your option, the Apache License version 2.0. You may obtain a copy 
# of the License at https://solderpad.org/licenses/SHL-2.1/
# 
# Unless required by applicable law or agreed to in writing, any work 
# distributed under the License is distributed on an “AS IS” BASIS, WITHOUT 
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
# License for the specific language governing permissions and limitations 
# under the License.

BASE_HEADER := "[SoC MAKEFILE]"
ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
SW_DIR := $(ROOT_DIR)/sw
SIM_OUT_BASE := $(ROOT_DIR)/verif/out

VERIF_DIR := $(ROOT_DIR)/verif
BENDER := bender
VERILATOR ?= verilator
V_FLAGS ?=
SIM_THREADS ?= 4
TARGET_CVA6_ISA := cv64a6_imafdc_sv39
VERILATED_TB := tb_boot_exe
PROGRAM ?= not_set
SKIP_ROM ?= 1
TRACE ?= 0
TIMEOUT ?= 500000
PATCH_DIR := $(ROOT_DIR)/patch
RI_PATH = $(shell $(BENDER) path register_interface)
REGGEN = $(RI_PATH)/vendor/lowrisc_opentitan/util/regtool.py
BROMGEN = $(ROOT_DIR)/utils/gen_bootrom.py
PYTHON = python

SIM_OUT_DIR := $(VERIF_DIR)/out/run-$(shell date +%Y-%m-%d)-$(PROGRAM)

PROGRAM_DIR := $(ROOT_DIR)/sw/$(PROGRAM)
PROGRAM_MAKEFILE := $(PROGRAM_DIR)/Makefile
MEMHEX := $(SIM_OUT_DIR)/program.hex

FLIST := $(VERIF_DIR)/soc.flist
SIM_BIN := $(VERIF_DIR)/build/$(VERILATED_TB)

.PHONY: getdeps patch build-program verilate run clean

getdeps: Bender.yml
	$(BENDER) update
	$(MAKE) patch

# Overlay locally-patched source files onto the bender dependency checkouts.
# Layout: patch/<dependency>/<path-relative-to-that-dependency-root>
#   e.g. patch/cva6/core/include/build_config_pkg.sv
# Each file replaces its upstream counterpart in `bender path <dependency>`.
# Copies are idempotent, so this is safe to re-run (e.g. after `bender update`).
patch:
	@if [ ! -d "$(PATCH_DIR)" ]; then \
		echo $(BASE_HEADER) No patch/ directory, nothing to apply; \
	else \
		for dep_dir in "$(PATCH_DIR)"/*/; do \
			[ -d "$$dep_dir" ] || continue; \
			dep="$$(basename "$$dep_dir")"; \
			dest_root="$$($(BENDER) path "$$dep" 2>/dev/null)"; \
			if [ -z "$$dest_root" ]; then \
				echo "$(BASE_HEADER) WARNING: '$$dep' is not a bender dependency, skipping"; \
				continue; \
			fi; \
			( cd "$$dep_dir" && find . -type f ) | sed 's|^\./||' | while read -r rel; do \
				src="$$dep_dir$$rel"; dst="$$dest_root/$$rel"; \
				if [ ! -s "$$src" ]; then \
					echo "$(BASE_HEADER) WARNING: patch/$$dep/$$rel is empty, skipping (unfilled placeholder?)"; \
				elif [ ! -f "$$dst" ]; then \
					echo "$(BASE_HEADER) WARNING: patch/$$dep/$$rel has no upstream counterpart at $$dst, skipping"; \
				else \
					cp "$$src" "$$dst"; \
					echo "$(BASE_HEADER) Patched $$dep/$$rel"; \
				fi; \
			done; \
		done; \
	fi

hw/uart/reg:
	mkdir -p hw/uart/reg
	$(PYTHON) $(REGGEN) -r -t ./hw/uart/reg ./hw/uart/uart.hjson 

hw/gpio/reg:
	mkdir -p hw/gpio/reg
	$(PYTHON) $(REGGEN) -r -t ./hw/gpio/reg ./hw/gpio/gpio.hjson 

hw/bootrom.sv: sw/bootrom/main.c sw/bootrom/crt.s sw/bootrom/link.ld
	$(eval include fpga/targets.mk)
	$(MAKE) -C sw/bootrom TARGET=synth CLK_FREQ=$(FPGA_CLK_FREQ) BAUDRATE=$(FPGA_BAUDRATE) 
	$(PYTHON) $(BROMGEN) --input sw/bootrom/build_synth/bootrom.hex --output hw/bootrom.sv

verif/sim_bootrom.sv: sw/bootrom/main.c sw/bootrom/crt.s sw/bootrom/link.ld
	$(MAKE) -C sw/bootrom TARGET=sim
	$(PYTHON) $(BROMGEN) --input sw/bootrom/build_sim/bootrom.hex --output verif/sim_bootrom.sv

peripherals: hw/uart/reg hw/gpio/reg

build-program:
	@if [ ! -f "$(PROGRAM_MAKEFILE)" ]; then \
		echo "$(BASE_HEADER) Unknown test '$(PROGRAM)' (no Makefile in sw/$(PROGRAM))"; \
		exit 1; \
	fi
	@echo $(BASE_HEADER) Building program $(PROGRAM)
	$(MAKE) -C "$(PROGRAM_DIR)" clean
	$(MAKE) -C "$(PROGRAM_DIR)"	SKIP_ROM=$(SKIP_ROM)

verilate: peripherals verif/sim_bootrom.sv
	mkdir -p $(SIM_OUT_BASE)
	mkdir -p $(SIM_OUT_DIR)

	@echo $(BASE_HEADER) Compiling the design
	$(BENDER) script flist-plus -t $(TARGET_CVA6_ISA) -t soc_verilate > tmp.flist
	# HPDCache does not compile, TODO: investigate, not used by the selected ISA, can be removed from flist
	grep -v "hpdcache" tmp.flist > "$(FLIST)"
	rm tmp.flist

	@bash -o pipefail -c '\
	"$(VERILATOR)" \
		--sv \
		--timing \
		--bbox-unsup \
		-Wno-TIMESCALEMOD \
		-Wno-fatal \
		--binary \
		-O3 \
		--threads "$(SIM_THREADS)" \
		-j 4 \
		--top-module tb_boot $(V_FLAGS)\
		$(if $(filter 1,$(TRACE)),--trace-fst --trace-structs) \
		-F "$(FLIST)" \
		-Mdir "$(VERIF_DIR)/build" \
		-o "$(VERILATED_TB)" | tee "$(SIM_OUT_DIR)/verilate_log.txt" \
	'

run: build-program verilate
	mkdir -p $(SIM_OUT_BASE)
	mkdir -p $(SIM_OUT_DIR)
	@echo $(BASE_HEADER) Copying build artifacts in output directory
	@elf_file="$$(find "$(PROGRAM_DIR)" -maxdepth 2 -type f -name '*.elf' | head -n 1)"; \
	hex_file="$$(find "$(PROGRAM_DIR)" -maxdepth 2 -type f -name '*.hex' | head -n 1)"; \
	cp "$$elf_file" "$(SIM_OUT_DIR)/program.elf"; \
	cp "$$hex_file" "$(MEMHEX)";
	@echo $(BASE_HEADER) Copied $$elf_file in $(SIM_OUT_DIR)/program.elf
	@echo $(BASE_HEADER) Copied $$hex_file in $(MEMHEX)
	@echo $(BASE_HEADER) Starting simulation
	"$(SIM_BIN)" +memhex="$(MEMHEX)" +timeout=$(TIMEOUT) +ramboot=$(SKIP_ROM) | tee $(SIM_OUT_DIR)/output.txt
	mv $(ROOT_DIR)/trace_hart_0.dasm $(SIM_OUT_DIR)/trace_hart_0.dasm 
	@echo $(BASE_HEADER) SoC simulation terminated
	@echo $(BASE_HEADER) Results transcripts and artifacts available at $(SIM_OUT_DIR)

fpga: peripherals hw/bootrom.sv
	$(eval include fpga/targets.mk)
	@echo $(BASE_HEADER) Starting FPGA synthesis for board $(BOARD)
	$(MAKE) -C fpga bitstream XDC=$(FPGA_XDCFNAME) PART_NAME=$(FPGA_PARTNAME)
	@echo $(BASE_HEADER) Synthesis terminated for board $(BOARD), check fpga/out directory for bitstream and reports

clean:
	@for dir in "$(SW_DIR)"/*; do \
		if [ -d "$$dir" ] && [ -f "$$dir/Makefile" ]; then \
			$(MAKE) -C "$$dir" clean; \
		fi; \
	done
	$(MAKE) -C fpga clean SKIP_XDC=1
	rm -rf "$(SIM_OUT_BASE)"
	rm -rf "$(VERIF_DIR)/build"
	rm -f "$(FLIST_RAW)" "$(FLIST)"
	rm -rf hw/uart/reg
	rm -rf hw/gpio/reg
	rm -rf hw/bootrom.sv
	rm -rf verif/sim_bootrom.sv

