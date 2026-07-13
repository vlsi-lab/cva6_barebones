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
#
# ML-KEM-512 (Kyber-512) with Ascon symmetric primitives, bare-metal RV64.
#
# COPRO=1 builds the tightly-coupled variant: the Ascon P12 permutation is
# provided by ascon_p12.S (xor3/xandn/drorx custom instructions) via the
# crypto coprocessor, instead of the pure-software C permutation.

COPRO ?= 0

BUILD_PREFIX := mlkem512$(if $(filter 1,$(COPRO)),_copro,)
ROOT_DIR := $(abspath $(CURDIR)/../..)
BUILD_DIR := ./build

SKIP_ROM ?= 0

# Kyber-512 + Ascon sources (mirrors run.sh)
SRC := \
	main.c \
	ascon.c \
	cbd.c \
	indcpa.c \
	kem.c \
	ntt.c \
	poly.c \
	polyvec.c \
	randombytes.c \
	reduce.c \
	symmetric-ascon.c \
	verify.c

ELF := $(BUILD_DIR)/$(BUILD_PREFIX).elf
BIN := $(BUILD_DIR)/$(BUILD_PREFIX).bin
HEX := $(BUILD_DIR)/$(BUILD_PREFIX).hex

TOOLCHAIN_PREFIX := riscv64-unknown-elf
CC := $(TOOLCHAIN_PREFIX)-gcc
OBJCOPY := $(TOOLCHAIN_PREFIX)-objcopy
PYTHON := python3

LDSCRIPT := $(ROOT_DIR)/sw/common/link.ld
BIN_TO_MEMHEX := $(ROOT_DIR)/utils/bin_to_memhex.py
CRT := $(ROOT_DIR)/sw/common/crt.s

CFLAGS := \
	-nostartfiles \
	-ffreestanding \
	-O2 \
	-ffunction-sections \
	-fdata-sections \
	-I. \
	-I../common \
	-DKYBER_K=2 \
	-march=rv64imac_zicsr_zifencei \
	-mabi=lp64 \
	-mcmodel=medany

LDFLAGS := \
	-T "$(LDSCRIPT)" \
	-Wl,--gc-sections \
	-Wl,--build-id=none

# Tightly-coupled (coprocessor) variant: swap the software P12 for the custom
# instruction routine shared with the Ascon standalone test.
ifeq ($(COPRO),1)
CFLAGS += -DUSE_COPROCESSOR_ASM
SRC    += $(ROOT_DIR)/sw/ascon/ascon_p12.S
endif

BASE_HEADER := "[SW COMPILE]"

.PHONY: all clean

all: $(HEX)

$(BUILD_DIR):
	mkdir -p "$@"

$(ELF): $(LDSCRIPT) $(CRT) $(SRC) | $(BUILD_DIR)
	"$(CC)" \
		$(CFLAGS) \
		"$(CRT)" \
		$(SRC) \
		$(LDFLAGS) \
		-o "$@"
	@echo $(BASE_HEADER) Compiling $@

$(BIN): $(ELF)
	"$(OBJCOPY)" -O binary "$<" "$@"

$(HEX): $(BIN)
	"$(PYTHON)" "$(BIN_TO_MEMHEX)" \
		--input "$<" \
		--output "$@" \
		--word-bytes 8 \
		$(if $(filter 0,$(SKIP_ROM)),--header)
	@echo $(BASE_HEADER) SRAM memfile generated at $@

clean:
	rm -rf "$(BUILD_DIR)"
