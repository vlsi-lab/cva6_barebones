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

# Board specific configurations
ifeq ($(BOARD),zynq7020db)
FPGA_CLK_FREQ := 50000000
FPGA_BAUDRATE := 115200
FPGA_XDCFNAME := zynq7020db.xdc
FPGA_PARTNAME := xc7z020clg484-2
else ifeq ($(BOARD),cw305)
FPGA_CLK_FREQ := 50000000
FPGA_BAUDRATE := 115200
FPGA_XDCFNAME := cw305.xdc
FPGA_PARTNAME := xc7a100tftg256-2
else
$(error Unsupported board $(BOARD))
endif