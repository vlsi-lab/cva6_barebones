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

module sim_uart #(
	parameter int clk_freq = 50000000,
	parameter int divider
) (
	input	logic clk_i,
	input	logic rst_ni,
	
	input	logic boot_en,

	output	logic tx_o
);
	typedef enum logic [2:0] {
		IDLE,
		READLINE,
		SET,
		TX,
		DONE
	} state_t;

	logic tick;
	logic busy;
	logic [7:0] txd;
	logic start;

	logic [63:0] line;
	int tx_idx;
	state_t driver_state;

	int fd;


	baud_gen #(clk_freq) i_baudgen (
		.clk_i 		(clk_i),
		.rst_ni 	(rst_ni),
		.divider_i	(divider),
		.tick_o		(tick),
		.tick8_o	()
	);

	uart_tx i_tx (
		.clk_i		(clk_i),
		.rst_ni		(rst_ni),
		.tick_i		(tick),
		.tx_i		(start),
		.txd_i		(txd),
		.tx_o		(tx_o),
		.busy_o		(busy)
	);

	initial begin
		string prog_hex;
		bit [63:0] word;

		if (!$value$plusargs("memhex=%s", prog_hex))
			$fatal(1, "Missing +memhex=<path-to-program.hex>");

		fd = $fopen(prog_hex, "r");
		if (fd == 0) 
			$fatal(1, "Cannot open program HEX in read mode");
	end

	always_ff @(posedge clk_i) begin
		if (!rst_ni) begin
			driver_state <= boot_en ? IDLE : DONE;
			txd <= 8'h00;
			tx_idx <= 0;
		end else begin
			case (driver_state)
				IDLE: begin
					start <= 1'b0;
					if (!$feof(fd)) begin
						$fscanf(fd, "%h", line);
						driver_state <= READLINE;
						tx_idx <= 0;
					end else begin
						driver_state <= DONE;
					end 
				end
				READLINE: begin
					txd <= line[tx_idx +: 8];
					start <= 1'b1;
					driver_state <= SET;
				end
				SET: driver_state <= TX;
				TX: begin
					start <= 1'b0;
					if (!busy) begin
						driver_state <= READLINE;
						if (tx_idx == 56) driver_state <= IDLE;
						else tx_idx <= tx_idx + 8;
					end
				end
				DONE: 		if (fd) $fclose(fd);
				default: 	driver_state <= DONE;
			endcase
		end
	end

endmodule