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

import uart_pkg::*;

module uart_rx (
	input	logic 		clk_i,
	input	logic 		rst_ni,

	input	logic 		tick_i,
	input	logic 		rx_i,

	output	logic 		valid_o,
	output	logic[7:0]	rxd_o
);

logic [1:0] rx_sync;
logic [2:0] rx_cnt;
logic [3:0] sample_cnt;
logic [7:0] data;

logic rx;
logic sample_start;
logic sample_data;

uart_state_t state;

// Two flops synchronizer
always_ff @(posedge clk_i) begin
	if (!rst_ni)	rx_sync <= '1;
	else			rx_sync <= {rx_sync[0], rx_i};
end

// Simple filter
always_ff @(posedge clk_i) begin
	if (!rst_ni) begin
		rx_cnt	<= '0;
		rx		<= 1'b1;
	end else begin
		if (rx_sync[1] && rx_cnt != 3'b111)			rx_cnt <= rx_cnt + 1;
		else if (!rx_sync[1] && rx_cnt != 3'b000)	rx_cnt <= rx_cnt - 1;

		if (rx_cnt == 3'b000)		rx <= 0;
		else if (rx_cnt == 3'b111)	rx <= 1;
	end
end

always_ff @(posedge clk_i) begin
	if (!rst_ni) state <= IDLE;
	else if (tick_i) begin
		case (state)
			IDLE: 		if (~rx) state <= START_BIT;
			START_BIT: 	if (sample_start) state <= ~rx ? B0 : IDLE;
			B0: 		if (sample_data) state <= B1;
			B1: 		if (sample_data) state <= B2;
			B2: 		if (sample_data) state <= B3;
			B3: 		if (sample_data) state <= B4;
			B4: 		if (sample_data) state <= B5;
			B5: 		if (sample_data) state <= B6;
			B6: 		if (sample_data) state <= B7;
			B7: 		if (sample_data) state <= STOP_BIT;
			STOP_BIT: 	if (sample_data) state <= IDLE;
			default: 	state <= IDLE;
		endcase
	end
end

always_ff @(posedge clk_i) begin
	if (!rst_ni) sample_cnt <= '0;
	else if (tick_i) begin
		if (state == IDLE)	sample_cnt <= '0;
		else if (state == START_BIT) begin
			if (sample_start) sample_cnt <= '0;
			else sample_cnt <= sample_cnt + 1;
		end else begin
			if (sample_data) sample_cnt <= '0;
			else sample_cnt <= sample_cnt + 1;
		end
	end
end
assign sample_start = sample_cnt == 7 ? 1'b1 : 1'b0;
assign sample_data = sample_cnt == 15 ? 1'b1 : 1'b0;

always_ff @(posedge clk_i) begin
	if (!rst_ni) begin
		data <= '0;
		rxd_o <= '0;
		valid_o <= '0;
	end else begin
		valid_o <= 1'b0;
		if (tick_i && sample_data && state[3]) begin
			data <= {rx, data[7:1]};
			if (state == B7) begin
				valid_o	<= 1'b1;
				rxd_o	<= {rx, data[7:1]};
			end
		end
	end
end

endmodule