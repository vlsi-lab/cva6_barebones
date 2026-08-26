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

module bb_sram #(
	parameter int unsigned ADDR_WIDTH = 64,
	parameter int unsigned DATA_WIDTH = 64,
	parameter int unsigned SIZE_BYTES = 18 * 1024 * 1024
)(
	input  logic                        clk_i,
	input  logic                        rst_ni,
	input  logic                        mem_req_i,
	input  logic [ADDR_WIDTH-1:0]       mem_addr_i,
	input  logic [DATA_WIDTH-1:0]       mem_wdata_i,
	input  logic [DATA_WIDTH/8-1:0]     mem_strb_i,
	input  logic                        mem_we_i,
	output logic                        mem_rvalid_o,
	output logic [DATA_WIDTH-1:0]       mem_rdata_o
);
	localparam int unsigned BYTES_PER_WORD = DATA_WIDTH / 8;
	localparam int unsigned DEPTH          = (SIZE_BYTES + BYTES_PER_WORD - 1) / BYTES_PER_WORD;
	localparam int unsigned ADDR_LSB       = $clog2(BYTES_PER_WORD);
	localparam int unsigned IDX_WIDTH      = (DEPTH > 1) ? $clog2(DEPTH) : 1;

	logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
	logic [IDX_WIDTH-1:0]  word_idx;

	always_comb begin
		word_idx = mem_addr_i[ADDR_LSB + IDX_WIDTH - 1 : ADDR_LSB];
	end

	always_ff @(posedge clk_i) begin
		if (!rst_ni) begin
			mem_rvalid_o <= 1'b0;
			mem_rdata_o  <= '0;
		end else begin
			mem_rvalid_o <= mem_req_i & ~mem_we_i;

			if (mem_req_i && mem_we_i) begin
				for (int unsigned byte_idx = 0; byte_idx < BYTES_PER_WORD; byte_idx++) begin
					if (mem_strb_i[byte_idx]) begin
						mem[word_idx][8*byte_idx +: 8] <= mem_wdata_i[8*byte_idx +: 8];
					end
				end
			end

			if (mem_req_i && !mem_we_i) begin
				mem_rdata_o <= mem[word_idx];
			end
		end
	end
endmodule