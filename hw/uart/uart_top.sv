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

`include "register_interface/typedef.svh"
`include "register_interface/assign.svh"

module uart #(
	parameter int			clk_freq,
	parameter int unsigned 	AXI_ADDR_WIDTH,
	parameter int unsigned 	AXI_DATA_WIDTH,
	parameter int unsigned 	AXI_ID_WIDTH,
	parameter int unsigned 	AXI_USER_WIDTH,
	parameter type 			axi_req_t,
  	parameter type 			axi_rsp_t
) (
	input	logic 		clk_i,
	input	logic 		rst_ni,
	input 	axi_req_t 	axi_req_i,
	output 	axi_rsp_t 	axi_rsp_o,
	input	logic 		rx_i,
	output	logic 		tx_o
);

	logic tick, tick8;
	logic [7:0] rxd, fifo_data;
	logic [7:0] txd;
	logic [$clog2(clk_freq-1)-1:0] divider;

	logic valid, busy, start, empty, data_rd;
	logic fifo_push, fifo_pop, fifo_full;

	// UART hardware 
	baud_gen #(clk_freq) i_baudgen (
		.clk_i 		(clk_i),
		.rst_ni 	(rst_ni),
		.divider_i	(divider),
		.tick_o		(tick),
		.tick8_o	(tick8)
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

	uart_rx i_rx (
		.clk_i		(clk_i),
		.rst_ni		(rst_ni),
		.tick_i		(tick8),
		.rx_i		(rx_i),
		.valid_o	(valid),
		.rxd_o		(rxd)
	);

	assign data_rd = 
		reg_req_i.valid && 
		~reg_req_i.write && 
		(reg_req_i.addr[uart_reg_pkg::BlockAw-1:0] == uart_reg_pkg::UART_RX_DATA_OFFSET);

	assign fifo_pop = data_rd && !empty;
	assign fifo_push = valid && !fifo_full;

	fifo_v3 #(
		.FALL_THROUGH(1'b1),
		.DATA_WIDTH(8),
		.DEPTH(cva6_barebones_pkg::uart_rx_fifo_depth)
	) i_rxfifo (
		.clk_i		(clk_i),
		.rst_ni		(rst_ni),
		.flush_i 	(1'b0),
		.testmode_i	(1'b0),
		.full_o 	(fifo_full),
		.empty_o	(empty),
		.data_i		(rxd),
		.push_i		(fifo_push),
		.data_o		(fifo_data),
		.pop_i		(fifo_pop)
	);

	// UART interface
	typedef logic [AXI_ADDR_WIDTH-1:0] 		addr_t;
	typedef logic [AXI_DATA_WIDTH-1:0] 		data_t;
	typedef logic [AXI_DATA_WIDTH/8-1:0] 	strb_t;

	`REG_BUS_TYPEDEF_REQ(reg_req_t, addr_t, data_t, strb_t);
	`REG_BUS_TYPEDEF_RSP(reg_rsp_t, data_t);

	uart_reg_pkg::uart_reg2hw_t	reg2hw;
	uart_reg_pkg::uart_hw2reg_t	hw2reg;
	reg_req_t 					reg_req_i;
	reg_rsp_t 					reg_rsp_o;

	axi_to_reg #(
		.ADDR_WIDTH	(AXI_ADDR_WIDTH),
		.DATA_WIDTH	(AXI_DATA_WIDTH),
		.ID_WIDTH	(AXI_ID_WIDTH),
		.USER_WIDTH	(AXI_USER_WIDTH),
		.DECOUPLE_W	(0),
		.axi_req_t	(axi_req_t),
		.axi_rsp_t	(axi_rsp_t),
		.reg_req_t	(reg_req_t),
		.reg_rsp_t	(reg_rsp_t)
	) i_axi2reg (
		.clk_i		(clk_i),
		.rst_ni		(rst_ni),
		.testmode_i	(1'b0),
		.axi_req_i	(axi_req_i),
		.axi_rsp_o	(axi_rsp_o),
		.reg_req_o	(reg_req_i), 
		.reg_rsp_i	(reg_rsp_o)
	);

	uart_reg_top # (
		.reg_req_t	(reg_req_t),
		.reg_rsp_t	(reg_rsp_t)
	) i_reg2uart (
		.clk_i		(clk_i),
		.rst_ni		(rst_ni),
		.reg_req_i	(reg_req_i),
		.reg_rsp_o	(reg_rsp_o),
		.reg2hw		(reg2hw),
		.hw2reg		(hw2reg),
		.devmode_i	(1'b0)
	);

	assign txd 		= reg2hw.tx_data.q;
	assign start 	= reg2hw.csreg.start.q;
	assign divider 	= reg2hw.divider.q[$size(divider)-1:0];
		
	assign hw2reg.rx_data.d 		= fifo_data;
	assign hw2reg.csreg.empty.d 	= empty;
	assign hw2reg.csreg.busy.d 		= busy;
	assign hw2reg.rx_data.de 		= 1'b1;
	assign hw2reg.csreg.empty.de 	= 1'b1;
	assign hw2reg.csreg.busy.de 	= 1'b1;
endmodule