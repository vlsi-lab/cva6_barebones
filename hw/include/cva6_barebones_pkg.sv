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

`include "cvxif_types.svh"
`include "axi/typedef.svh"
`include "rvfi_types.svh"

package cva6_barebones_pkg;
	// Boot address configuration
	localparam logic [63:0] boot_addr = 64'h0001_0000;

	// SRAM Configurations
	localparam int unsigned sram_size = 256 * 1024; // By default 256 KB instantiated

	// Peripherals config
	localparam int unsigned uart_rx_fifo_depth = 64;
	
	// AXI Crossbar configuration
	localparam int unsigned axi_master_cnt = 1; // Number of bus masters on the AXI crossbar
	localparam int unsigned axi_periph_cnt = 4; // Number of peripherals on the AXI crossbar

	// AXI Peripherals and address map
	typedef enum int unsigned {
		DEV_SRAM = 0,
		DEV_UART = 1,
		DEV_BROM = 2,
		DEV_GPIO = 3
	} axi_peripherals;
	
	localparam axi_pkg::xbar_rule_64_t [axi_periph_cnt-1:0] addr_map = '{
		'{ idx: DEV_SRAM, start_addr: 64'h8000_0000, end_addr: 64'h8000_0000 + 64'h0180_0000 },
		'{ idx: DEV_UART, start_addr: 64'h1000_0000, end_addr: 64'h1000_0000 + 64'h0000_1000 },
		'{ idx: DEV_BROM, start_addr: 64'h0001_0000, end_addr: 64'h0001_0000 + 64'h0001_0000 },
		'{ idx: DEV_GPIO, start_addr: 64'h1000_1000, end_addr: 64'h1000_1000 + 64'h0000_1000 }
	};

	// ---------------------------------------------------
	// | STOP: Type definitions for CVA6 - Do not Touch! |
	// ---------------------------------------------------	

	// CVA6 Configuration 
	localparam config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(core_config_pkg::cva6_cfg);

	// CVXIF Types
	typedef `READREGFLAGS_T(CVA6Cfg)															readregflags_t;
   	typedef `WRITEREGFLAGS_T(CVA6Cfg)															writeregflags_t;
   	typedef `ID_T(CVA6Cfg)																		id_t;
   	typedef `HARTID_T(CVA6Cfg)																	hartid_t;
   	typedef `X_COMPRESSED_REQ_T(CVA6Cfg, hartid_t)												x_compressed_req_t;
   	typedef `X_COMPRESSED_RESP_T(CVA6Cfg)														x_compressed_resp_t;
   	typedef `X_ISSUE_REQ_T(CVA6Cfg, hartid_t, id_t)												x_issue_req_t;
   	typedef `X_ISSUE_RESP_T(CVA6Cfg, writeregflags_t, readregflags_t)							x_issue_resp_t;
   	typedef `X_REGISTER_T(CVA6Cfg, hartid_t, id_t, readregflags_t)								x_register_t;
   	typedef `X_COMMIT_T(CVA6Cfg, hartid_t, id_t)												x_commit_t;
   	typedef `X_RESULT_T(CVA6Cfg, hartid_t, id_t, writeregflags_t)								x_result_t;
   	typedef `CVXIF_REQ_T(CVA6Cfg, x_compressed_req_t, x_issue_req_t, x_register_t, x_commit_t)	cvxif_req_t;
   	typedef `CVXIF_RESP_T(CVA6Cfg, x_compressed_resp_t, x_issue_resp_t, x_result_t) 			cvxif_resp_t;

	// AXI Types
	localparam int unsigned AxiAddrWidth 		= core_config_pkg::CVA6ConfigAxiAddrWidth;
	localparam int unsigned AxiDataWidth 		= core_config_pkg::CVA6ConfigAxiDataWidth;
	localparam int unsigned AxiIdWidth   		= core_config_pkg::CVA6ConfigAxiIdWidth;
	localparam int unsigned AxiIdWidthSlave		= core_config_pkg::CVA6ConfigAxiIdWidth + $clog2(axi_master_cnt);
	localparam int unsigned AxiUserWidth 		= core_config_pkg::CVA6ConfigDataUserWidth;

	typedef logic [AxiAddrWidth-1:0]	axi_addr_t;
	typedef logic [AxiIdWidth-1:0]		axi_id_t;
	typedef logic [AxiIdWidthSlave-1:0]	axi_id_slave_t;
	typedef logic [AxiDataWidth-1:0]	axi_data_t;
	typedef logic [AxiDataWidth/8-1:0]	axi_strb_t;
	typedef logic [AxiUserWidth-1:0]	axi_user_t;

	`AXI_TYPEDEF_ALL(axi, axi_addr_t, axi_id_t, axi_data_t, axi_strb_t, axi_user_t)

	typedef axi_req_t     noc_req_t;
	typedef axi_resp_t    noc_resp_t;

	// RVFI types
	typedef `RVFI_PROBES_INSTR_T(CVA6Cfg) rvfi_probes_instr_t;
	typedef `RVFI_PROBES_CSR_T(CVA6Cfg) rvfi_probes_csr_t;
	typedef struct packed {
		rvfi_probes_csr_t csr;
		rvfi_probes_instr_t instr;
	} rvfi_probes_t;

	// AXI Crossbar configuration
	localparam axi_pkg::xbar_cfg_t AXI_XBAR_CFG = '{
		NoSlvPorts: unsigned'(axi_master_cnt),
		NoMstPorts: unsigned'(axi_periph_cnt),
		MaxMstTrans: unsigned'(1), // Probably requires update
		MaxSlvTrans: unsigned'(1), // Probably requires update
		FallThrough: 1'b0,
		LatencyMode: axi_pkg::NO_LATENCY,
		AxiIdWidthSlvPorts: unsigned'(AxiIdWidth),
		AxiIdUsedSlvPorts: unsigned'(AxiIdWidth),
		UniqueIds: 1'b0,
		AxiAddrWidth: unsigned'(AxiAddrWidth),
		AxiDataWidth: unsigned'(AxiDataWidth),
		NoAddrRules: unsigned'(axi_periph_cnt)
	};
endpackage