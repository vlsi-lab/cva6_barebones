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

TARGET_CVA6_ISA := cv64a6_imafdc_sv39

SYNTH_OUT_DIR := ./out/run-$(shell date +%Y-%m-%d)

BENDER := bender
VIVADO := vivado

SKIP_XDC ?= 0

ifeq ($(SKIP_XDC),0)
ifndef XDC
$(error XDC is not set. Please provide XDC when calling make)
endif
ifndef PART_NAME
$(error PART_NAME is not set. Please provide PART_NAME when calling make)
endif

endif

.PHONY: bitstream

bitstream: scripts/import_sources.tcl
	rm -rf build
	mkdir -p $(SYNTH_OUT_DIR)
	$(VIVADO) -mode batch -source scripts/xilinx_build.tcl -tclargs $(XDC) $(PART_NAME)
	mv syn_timing.rpt $(SYNTH_OUT_DIR)/syn_timing.rpt 
	mv syn_power.rpt $(SYNTH_OUT_DIR)/syn_power.rpt 
	mv syn_utilization.rpt $(SYNTH_OUT_DIR)/syn_utilization.rpt 
	mv impl_timing.rpt $(SYNTH_OUT_DIR)/impl_timing.rpt 
	mv impl_power.rpt $(SYNTH_OUT_DIR)/impl_power.rpt 
	mv impl_utilization.rpt $(SYNTH_OUT_DIR)/impl_utilization.rpt 
	mv scripts/import_sources.tcl $(SYNTH_OUT_DIR)/used_sources.tcl
	cp build/cva6_barebones.runs/impl_1/cva6_barebones.bit $(SYNTH_OUT_DIR)/cva6_barebones.bit

scripts/import_sources.tcl:
	$(BENDER) script vivado -t $(TARGET_CVA6_ISA) --dir ../ > ./scripts/import_sources.tcl

clean:
	rm -f scripts/import_sources.tcl
	rm -f *.log *.jou *.str
	rm -rf .Xil
	rm -rf build
	rm -rf out