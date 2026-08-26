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

`include "axi/assign.svh"

module cva6_barebones (
	input 	logic		clk_i,
	input 	logic		rst_ni,

	input	logic		rx_i,
	output	logic		tx_o,
	
	inout	logic[7:0]	gpio_io
);
	import cva6_barebones_pkg::*;

	// AXI Crossbar
	AXI_BUS #(
		.AXI_ADDR_WIDTH (AxiAddrWidth),
		.AXI_DATA_WIDTH (AxiDataWidth),
		.AXI_ID_WIDTH   (AxiIdWidth),
		.AXI_USER_WIDTH (AxiUserWidth)
	) slave[axi_master_cnt-1:0]();

	AXI_BUS #(
		.AXI_ADDR_WIDTH (AxiAddrWidth),
		.AXI_DATA_WIDTH (AxiDataWidth),
		.AXI_ID_WIDTH   (AxiIdWidthSlave),
		.AXI_USER_WIDTH (AxiUserWidth)
	) master[axi_periph_cnt-1:0]();

	axi_xbar_intf #(
		.AXI_USER_WIDTH (AxiUserWidth),
		.Cfg            (AXI_XBAR_CFG),
		.rule_t         (axi_pkg::xbar_rule_64_t)
	) i_axi_xbar (
		.clk_i                 (clk_i),
		.rst_ni                (rst_ni),
		.test_i                ('0),
		.slv_ports             (slave),
		.mst_ports             (master),
		.addr_map_i            (addr_map),
		.en_default_mst_port_i ('0),
		.default_mst_port_i    ('0)
	);

	// Core instantiation
	cvxif_req_t 	cvxif_req;
  	cvxif_resp_t	cvxif_resp;

	noc_req_t		core_axi_req;
	noc_resp_t		core_axi_resp;

	cva6 #(
		.CVA6Cfg (CVA6Cfg),
		.rvfi_probes_instr_t (rvfi_probes_instr_t),
		.rvfi_probes_csr_t (rvfi_probes_csr_t),
		.rvfi_probes_t (rvfi_probes_t),
		.axi_ar_chan_t (axi_ar_chan_t),
		.axi_aw_chan_t (axi_aw_chan_t),
		.axi_w_chan_t (axi_w_chan_t),
		.noc_req_t (noc_req_t),
		.noc_resp_t (noc_resp_t),
		.readregflags_t (readregflags_t),
		.writeregflags_t (writeregflags_t),
		.id_t (id_t),
		.hartid_t (hartid_t),
		.x_compressed_req_t (x_compressed_req_t),
		.x_compressed_resp_t (x_compressed_resp_t),
		.x_issue_req_t (x_issue_req_t),
		.x_issue_resp_t (x_issue_resp_t),
		.x_register_t (x_register_t),
		.x_commit_t (x_commit_t),
		.x_result_t (x_result_t),
		.cvxif_req_t (cvxif_req_t),
		.cvxif_resp_t (cvxif_resp_t)
	) i_cva6 (
		.clk_i                ( clk_i ),
		.rst_ni               ( rst_ni ),
		.boot_addr_i          ( boot_addr ), 
		.hart_id_i            ( '0 ),
		.irq_i                ( '0 ),
		.ipi_i                ( '0 ),
		.time_irq_i           ( 1'b0 ), //TODO: implement timer irq
		.debug_req_i          ( 1'b0 ), //TOOD: implement debug irq
		.cvxif_req_o          ( cvxif_req ),
		.cvxif_resp_i         ( cvxif_resp ),
		.noc_req_o            ( core_axi_req ),
		.noc_resp_i           ( core_axi_resp )
	);

	// By default the XIF coprocessor is not instantiated
	assign cvxif_resp = '0;

	`AXI_ASSIGN_FROM_REQ(slave[0], core_axi_req)
  	`AXI_ASSIGN_TO_RESP(core_axi_resp, slave[0])	

	// SRAM
	logic						sram_mem_req;
	logic [AxiAddrWidth-1:0]	sram_mem_addr;
	logic [AxiDataWidth-1:0]	sram_mem_wdata;
	logic [AxiDataWidth/8-1:0]	sram_mem_strb;
	logic [AxiUserWidth-1:0]	sram_mem_user_w;
	logic						sram_mem_we;
	logic [AxiUserWidth-1:0]	sram_mem_user_r;
	logic [AxiDataWidth-1:0]	sram_mem_rdata;

	// TODO: switch to axi_to_mem_intf
	axi2mem #(
		.AXI_ID_WIDTH	(AxiIdWidthSlave),
		.AXI_ADDR_WIDTH	(AxiAddrWidth),
		.AXI_DATA_WIDTH	(AxiDataWidth),
		.AXI_USER_WIDTH	(AxiUserWidth)
	) i_sram_axiconv (
		.clk_i	(clk_i),
		.rst_ni	(rst_ni),
		.slave	(master[DEV_SRAM]),
		.req_o	(sram_mem_req),
		.we_o	(sram_mem_we),
		.addr_o	(sram_mem_addr),
		.be_o	(sram_mem_strb),
		.user_o	(sram_mem_user_w),
		.data_o	(sram_mem_wdata),
		.user_i	(sram_mem_user_r),
		.data_i	(sram_mem_rdata)
	);

	bb_sram #(
		.ADDR_WIDTH	(AxiAddrWidth),
		.DATA_WIDTH	(AxiDataWidth),
		.SIZE_BYTES	(sram_size)
	) i_sram (
		.clk_i			(clk_i),
		.rst_ni			(rst_ni),
		.mem_req_i		(sram_mem_req),
		.mem_addr_i		(sram_mem_addr),
		.mem_wdata_i	(sram_mem_wdata),
		.mem_strb_i 	(sram_mem_strb),
		.mem_we_i 		(sram_mem_we),
		.mem_rvalid_o 	(),
		.mem_rdata_o 	(sram_mem_rdata)
	);

	assign sram_mem_user_r = '0;

	// UART
	noc_req_t 	uart_req;
 	noc_resp_t	uart_resp;
	
  	`AXI_ASSIGN_TO_REQ(uart_req, master[DEV_UART])
  	`AXI_ASSIGN_FROM_RESP(master[DEV_UART], uart_resp)

	uart #(
		.clk_freq		(50000000),
		.AXI_ADDR_WIDTH	(AxiAddrWidth),
		.AXI_DATA_WIDTH	(AxiDataWidth),
		.AXI_ID_WIDTH	(AxiIdWidth),
		.AXI_USER_WIDTH	(AxiUserWidth),
		.axi_req_t		(noc_req_t),
		.axi_rsp_t		(noc_resp_t)
	) i_uart (
		.clk_i		(clk_i),
		.rst_ni 	(rst_ni),
		.axi_req_i	(uart_req),
		.axi_rsp_o	(uart_resp),
		.rx_i	(rx_i),
		.tx_o	(tx_o)
	);

	// BootROM
	logic						bootrom_req;
	logic [AxiAddrWidth-1:0]	bootrom_addr;
	logic [AxiDataWidth-1:0]	bootrom_data;

	axi2mem #(
		.AXI_ID_WIDTH	(AxiIdWidthSlave),
		.AXI_ADDR_WIDTH	(AxiAddrWidth),
		.AXI_DATA_WIDTH	(AxiDataWidth),
		.AXI_USER_WIDTH	(AxiUserWidth)
	) i_brom_axiconv (
		.clk_i	(clk_i),
		.rst_ni	(rst_ni),
		.slave	(master[DEV_BROM]),
		.req_o	(bootrom_req),
		//.we_o	(),
		.addr_o	(bootrom_addr),
		//.be_o	(),
		//.user_o	(),
		//.data_o	(),
		.user_i	('0),
		.data_i	(bootrom_data)
	);

	bootrom i_bootrom (
		.clk_i		( clk_i			),
		.req_i		( bootrom_req	),
		.addr_i		( bootrom_addr	),
		.data_o		( bootrom_data	)
	);

	// GPIO
	noc_req_t 	gpio_req;
 	noc_resp_t	gpio_resp;
	
  	`AXI_ASSIGN_TO_REQ(gpio_req, master[DEV_GPIO])
  	`AXI_ASSIGN_FROM_RESP(master[DEV_GPIO], gpio_resp)

	gpio_top #(
		.AXI_ADDR_WIDTH	(AxiAddrWidth),
		.AXI_DATA_WIDTH	(AxiDataWidth),
		.AXI_ID_WIDTH	(AxiIdWidth),
		.AXI_USER_WIDTH	(AxiUserWidth),
		.axi_req_t		(noc_req_t),
		.axi_rsp_t		(noc_resp_t)
	) i_gpio (
		.clk_i		(clk_i),
		.rst_ni 	(rst_ni),
		.axi_req_i	(gpio_req),
		.axi_rsp_o	(gpio_resp),
		.gpio_io	(gpio_io)
	);

	// Keccak accelerator (loosely-coupled AXI slave) @ 0x5000_1000
	noc_req_t 	keccak_req;
 	noc_resp_t	keccak_resp;
	logic		keccak_intr;

  	`AXI_ASSIGN_TO_REQ(keccak_req, master[DEV_KECCAK])
  	`AXI_ASSIGN_FROM_RESP(master[DEV_KECCAK], keccak_resp)

	keccak_axi_top #(
		.AXI_ADDR_WIDTH	(AxiAddrWidth),
		.AXI_DATA_WIDTH	(AxiDataWidth),
		.AXI_ID_WIDTH	(AxiIdWidth),
		.AXI_USER_WIDTH	(AxiUserWidth),
		.axi_req_t		(noc_req_t),
		.axi_rsp_t		(noc_resp_t)
	) i_keccak (
		.clk_i			(clk_i),
		.rst_ni 		(rst_ni),
		.test_mode_i	(1'b0),
		.axi_req_i		(keccak_req),
		.axi_rsp_o		(keccak_resp),
		.keccak_intr_o	(keccak_intr)
	);


endmodule