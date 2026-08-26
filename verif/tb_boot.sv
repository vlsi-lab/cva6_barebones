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

`timescale 1ns/1ps

module tb_boot;
	localparam time CLK_PERIOD = 20ns;
	localparam logic [63:0] SIG_ADDR  = 64'h8000_1000;
	localparam logic [63:0] SIG_VALUE = 64'hDEAD_BEEF_CAFE_BABE;
	localparam int unsigned SIG_WORD_IDX = (SIG_ADDR - 64'h8000_0000) >> 3;

	logic clk_i;
	logic rst_ni;
	logic clk_uart, rst_ni_uart;

	string mem_hex;
	int unsigned timeout;
	int unsigned ram_boot;
	int unsigned cycle_count;
	int unsigned gpr_idx;
	logic tx_start_q;
	logic uart_boot_en;

	task automatic dump_core;
		$display("[SoC TESTBENCH] ===== CORE DUMP @ cycle %0d =====", cycle_count);
		for (gpr_idx = 0; gpr_idx < 32; gpr_idx += 4) begin
			$display("[SoC TESTBENCH] x%-2d = 0x%016h x%-2d = 0x%016h x%-2d = 0x%016h x%-2d = 0x%016h",
				gpr_idx,
				dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[gpr_idx],
				gpr_idx + 1,
				dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[gpr_idx + 1],
				gpr_idx + 2,
				dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[gpr_idx + 2],
				gpr_idx + 3,
				dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[gpr_idx + 3]
			);
		end
		$display("[SoC TESTBENCH] commit pc = 0x%016h", dut.i_cva6.pc_commit);
		$write("[SoC TESTBENCH] =================================\n");
	endtask

	logic tx;
	cva6_barebones dut (
		.clk_i (clk_i),
		.rst_ni (rst_ni),
		.rx_i (tx)
	);

	sim_uart #(
		.divider(1)
	) i_romtx (
		.clk_i (clk_uart),
		.rst_ni(rst_ni_uart),
		.boot_en(uart_boot_en),
		.tx_o (tx)
	);

	initial begin
		clk_i = 1'b0;
		tx_start_q <= 1'b0;
		clk_uart = 1'b0;
        fork
        	forever #(CLK_PERIOD/2)		clk_i = ~clk_i;
			#3 forever #(CLK_PERIOD/2)	clk_uart = ~clk_uart;
		join
	end

	initial begin
		rst_ni = 1'b0;
		rst_ni_uart = 1'b0;
		cycle_count = 0;

		$dumpfile("tb_boot.vcd");
		$dumpvars(0);

		if (!$value$plusargs("memhex=%s", mem_hex)) begin
			$fatal(1, "Missing +memhex=<path-to-program.hex>");
		end

		if (!$value$plusargs("timeout=%d", timeout)) begin
			$fatal(1, "Missing +timeout=<timeout-in-cycles>");
		end

		if (!$value$plusargs("ramboot=%d", ram_boot)) begin
			$fatal(1, "Missing +ramboot=<skip-bootrom>");
		end

		if (ram_boot == 1) begin
			$display("[SoC TESTBENCH] Selected boot from RAM");
			$display("[SoC TESTBENCH] Loading SRAM image from %s", mem_hex);
			force dut.i_cva6.boot_addr_i = 64'h8000_0000;
			$readmemh(mem_hex, dut.i_sram.mem);
			uart_boot_en = 1'b0;
		end else begin
			$display("[SoC TESTBENCH] Selected boot from BootROM");
			uart_boot_en = 1'b1;
		end

		repeat (10) @(posedge clk_i);
		rst_ni = 1'b1;
		$display("[SoC TESTBENCH] rst_ni released");
		
		wait (dut.i_uart.divider != 0);
		repeat (4) @(posedge clk_i);
		rst_ni_uart = 1'b1;
	end

	always @(posedge clk_i) begin
		if (!rst_ni) begin
			cycle_count <= 0;
			tx_start_q <= 1'b0;
		end else begin
			cycle_count <= cycle_count + 1;
			tx_start_q <= dut.i_uart.start;

			if (dut.i_sram.mem[SIG_WORD_IDX] == SIG_VALUE) begin
				$display("\n[SoC TESTBENCH] Signature detected at cycle %0d", cycle_count);
				dump_core();
				if (dut.i_cva6.issue_stage_i.i_issue_read_operands.gen_asic_regfile.i_ariane_regfile.mem[10] != '0) begin
					$display("[SoC TESTBENCH] FAIL: main returned a non zero value. Check core dump for more details");
					$fatal(1, "main returned a non zero value");
				end
					
				$display("[SoC TESTBENCH] PASS: main returned 0");
				$finish;
			end

			if (dut.i_cva6.csr_regfile_i.mcause_q != '0) begin
				case (dut.i_cva6.csr_regfile_i.mcause_q[3:0])
					64'd0:  $display("\n[SoC TESTBENCH] Unexpected trap: Instruction address misaligned");
					64'd1:  $display("\n[SoC TESTBENCH] Unexpected trap: Instruction access fault");
					64'd2:  $display("\n[SoC TESTBENCH] Unexpected trap: Illegal instruction");
					64'd3:  $display("\n[SoC TESTBENCH] Unexpected trap: Breakpoint (ebreak)");
					64'd4:  $display("\n[SoC TESTBENCH] Unexpected trap: Load address misaligned");
					64'd5:  $display("\n[SoC TESTBENCH] Unexpected trap: Load access fault");
					64'd6:  $display("\n[SoC TESTBENCH] Unexpected trap: Store/AMO address misaligned");
					64'd7:  $display("\n[SoC TESTBENCH] Unexpected trap: Store/AMO access fault");
					64'd8:  $display("\n[SoC TESTBENCH] Unexpected trap: Environment call from U-mode (ecall)");
					64'd9:  $display("\n[SoC TESTBENCH] Unexpected trap: Environment call from S-mode (ecall)");
					64'd11: $display("\n[SoC TESTBENCH] Unexpected trap: Environment call from M-mode (ecall)");
					64'd12: $display("\n[SoC TESTBENCH] Unexpected trap: Instruction page fault");
					64'd13: $display("\n[SoC TESTBENCH] Unexpected trap: Load page fault");
					64'd15: $display("\n[SoC TESTBENCH] Unexpected trap: Store/AMO page fault");
					default:$display("\n[SoC TESTBENCH] Unexpected trap: Unknown exception (code=%0d)", dut.i_cva6.csr_regfile_i.mcause_q[62:0]);
            	endcase
				$display("[SoC TESTBENCH] mepc  = 0x%016h", dut.i_cva6.csr_regfile_i.mepc_q);
				$display("[SoC TESTBENCH] mtval = 0x%016h", dut.i_cva6.csr_regfile_i.mtval_q);
				dump_core();
				$display("[SoC TESTBENCH] FAIL: Exception caught, see log for details");
				$fatal(1, "exception caught");
			end

			if (cycle_count > timeout) begin
				$display("\n[SoC TESTBENCH] Cycles timeout");
				dump_core();
				$display("[SoC TESTBENCH] FAIL: Signature was not written before simulation timeout");
				$fatal(1, "signature not written");
			end

			if (dut.i_uart.start && !tx_start_q)
				$write("%c", dut.i_uart.txd);
		end
	end
endmodule