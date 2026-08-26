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

BUILD_PREFIX := bootrom
TARGET ?= sim
ifeq ($(TARGET),synth)
ifndef CLK_FREQ
$(error CLK_FREQ is not set. Please provide CLK_FREQ when calling make)
endif
ifndef BAUDRATE
$(error BAUDRATE is not set. Please provide BAUDRATE when calling make)
endif
endif
ROOT_DIR := $(abspath $(CURDIR)/../..)
BUILD_DIR := ./build_$(TARGET)

SRC := main.c

ELF := $(BUILD_DIR)/$(BUILD_PREFIX).elf
BIN := $(BUILD_DIR)/$(BUILD_PREFIX).bin
HEX := $(BUILD_DIR)/$(BUILD_PREFIX).hex

TOOLCHAIN_PREFIX := riscv64-unknown-elf
CC := $(TOOLCHAIN_PREFIX)-gcc
OBJCOPY := $(TOOLCHAIN_PREFIX)-objcopy
PYTHON := python3

LDSCRIPT := link.ld
BIN_TO_MEMHEX := $(ROOT_DIR)/utils/bin_to_memhex.py
CRT := crt.s

CFLAGS := \
	-nostdlib \
	-ffreestanding \
	-Os \
	-ffunction-sections \
	-fno-unwind-tables \
	-fno-asynchronous-unwind-tables \
	-fno-stack-protector \
	-I../common \
	-march=rv64imac_zicsr_zifencei \
	-mabi=lp64 \
	-mcmodel=medlow \
	$(if $(filter synth,$(TARGET)),-DSYNTHESIS -DCLK_FREQ=$(CLK_FREQ) -DBAUDRATE=$(BAUDRATE))

LDFLAGS := \
	-T "$(LDSCRIPT)" \
	-Wl,--gc-sections \
	-Wl,--build-id=none

BASE_HEADER := "[BOOTROM]"

.PHONY: all clean

all: $(HEX)

$(BUILD_DIR):
	mkdir -p "$@"

$(ELF): $(LDSCRIPT) $(CRT) $(SRC) | $(BUILD_DIR)	
	"$(CC)" \
		-nostartfiles \
		$(CFLAGS) \
		"$(CRT)" \
		"$(SRC)" \
		$(LDFLAGS) \
		-o "$@"
	@echo $(BASE_HEADER) Compiling BootROM

$(BIN): $(ELF)
	"$(OBJCOPY)" -O binary "$<" "$@"

$(HEX): $(BIN)
	"$(PYTHON)" "$(BIN_TO_MEMHEX)" \
		--input "$<" \
		--output "$@" \
		--word-bytes 8
	@echo $(BASE_HEADER) BootROM generated generated at $@

clean:
	rm -rf ./build*