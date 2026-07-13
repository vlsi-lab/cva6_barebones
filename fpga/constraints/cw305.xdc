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

set_property -dict {PACKAGE_PIN N13  IOSTANDARD LVCMOS33} [get_ports clk_i]
set_property -dict {PACKAGE_PIN R1   IOSTANDARD LVCMOS33} [get_ports rst_ni]
set_property -dict {PACKAGE_PIN E15  IOSTANDARD LVCMOS33} [get_ports rx_i]
set_property -dict {PACKAGE_PIN E13  IOSTANDARD LVCMOS33} [get_ports tx_o]
set_property -dict {PACKAGE_PIN T14  IOSTANDARD LVCMOS33} [get_ports {gpio_io[0]}]

# unused
set_property -dict {PACKAGE_PIN A12 IOSTANDARD LVCMOS33} [get_ports {gpio_io[1]}]
set_property -dict {PACKAGE_PIN A14 IOSTANDARD LVCMOS33} [get_ports {gpio_io[2]}]
set_property -dict {PACKAGE_PIN A15 IOSTANDARD LVCMOS33} [get_ports {gpio_io[3]}]
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports {gpio_io[4]}]
set_property -dict {PACKAGE_PIN B14 IOSTANDARD LVCMOS33} [get_ports {gpio_io[5]}]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports {gpio_io[6]}]
set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS33} [get_ports {gpio_io[7]}]

create_clock -period 20.0 [get_ports clk_i]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]