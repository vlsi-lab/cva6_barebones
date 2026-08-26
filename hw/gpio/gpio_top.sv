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

module gpio_top #(
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
	inout	logic[7:0]	gpio_io
);
	// GPIO interface
	typedef logic [AXI_ADDR_WIDTH-1:0] 		addr_t;
	typedef logic [AXI_DATA_WIDTH-1:0] 		data_t;
	typedef logic [AXI_DATA_WIDTH/8-1:0] 	strb_t;

	`REG_BUS_TYPEDEF_REQ(reg_req_t, addr_t, data_t, strb_t);
	`REG_BUS_TYPEDEF_RSP(reg_rsp_t, data_t);

	gpio_reg_pkg::gpio_reg2hw_t	reg2hw;
	gpio_reg_pkg::gpio_hw2reg_t	hw2reg;
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

	gpio_reg_top # (
		.reg_req_t	(reg_req_t),
		.reg_rsp_t	(reg_rsp_t)
	) i_reg2gpio (
		.clk_i		(clk_i),
		.rst_ni		(rst_ni),
		.reg_req_i	(reg_req_i),
		.reg_rsp_o	(reg_rsp_o),
		.reg2hw		(reg2hw),
		.hw2reg		(hw2reg),
		.devmode_i	(1'b0)
	);

	// GPIO Logic
	logic [7:0] odr;
	logic [7:0] idr;
	logic [7:0] ddr;

	gpio #(8) i_gpio_logic (
		.clk_i(clk_i),
		.rst_ni(rst_ni),
		.ddr_i(ddr),
		.odr_i(odr),
		.idr_o(idr),
		.ports_io(gpio_io)
	);

	assign ddr 				= reg2hw.ddr.q;
	assign odr 				= reg2hw.odr.q;
	assign hw2reg.idr.de	= 1'b1;
	assign hw2reg.idr.d		= idr;
endmodule