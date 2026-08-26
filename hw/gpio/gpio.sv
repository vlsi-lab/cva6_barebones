// Copyright 2026 Federico Runco (federico.runco@gmail.com)
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// 
// Licensed under the Solderpad Hardware License v2.1 (the “License”); 
// you may not use this file except in compliance with the License, or, 
// at your option, the Apache License version 2.0. You may obtain a copy 
// of the License at https://solderpad.org/licenses/SHL-2.1/
// 
// Unless required by applicable law or agreed to in writing, any work 
// distributed under the License is distributed on an “AS IS” BASIS, WITHOUT 
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
// License for the specific language governing permissions and limitations 
// under the License.

module gpio #(
	parameter int PORTS = 8
) (
	input	logic	clk_i,
	input	logic	rst_ni,

	input	logic [PORTS-1:0] ddr_i,
	input	logic [PORTS-1:0] odr_i,
	output	logic [PORTS-1:0] idr_o,

	inout	logic [PORTS-1:0] ports_io
);
	logic [PORTS-1:0] gpio_in;
	logic [PORTS-1:0] gpio_in_sync;

	// Input synchronizer
	logic [PORTS-1:0] in1_q, in2_q;

	always_ff @(posedge clk_i) begin
		if (!rst_ni) begin
			in1_q <= '0;
			in2_q <= '0;
		end else begin
			in1_q <= gpio_in;
			in2_q <= in1_q;
		end
	end

	assign idr_o = in2_q;

	// Tristate port generator
	genvar i;
	generate
		for (i=0; i < PORTS; i++) begin
			`ifndef VERILATOR
				IOBUF i_iobuf (
					.IO  (ports_io[i]),
					.I   (odr_i[i]),
					.O   (gpio_in[i]),
					.T   (~ddr_i[i])
				);
			`else
				assign ports_io[i] = ddr_i[i] ? odr_i[i] : 1'bz;
				assign gpio_in[i]  = ports_io[i];
			`endif
		end
	endgenerate

endmodule