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

if { $argc != 2 } {
	puts "Synthesis scripts requires XDC filename and part identifier"
	exit
}

set xdc_file [lindex $argv 0]
set part_name [lindex $argv 1]

create_project -force cva6_barebones ./build -part $part_name

source scripts/import_sources.tcl
set_property top cva6_barebones [current_fileset]

read_xdc "./constraints/$xdc_file"

launch_runs synth_1
wait_on_run synth_1
open_run synth_1 -name netlist_1

report_timing_summary -delay_type max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -file syn_timing.rpt
report_power -file syn_power.rpt
report_utilization -hierarchical  -file syn_utilization.rpt

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1
open_run impl_1 -name netlist_2

report_timing_summary -delay_type max -report_unconstrained -check_timing_verbose -max_paths 10 -input_pins -file impl_timing.rpt
report_power -file impl_power.rpt
report_utilization -hierarchical  -file impl_utilization.rpt
