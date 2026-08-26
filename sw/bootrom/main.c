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

#define BOOTROM
#include <stdint.h>
#include "uart.h"
#include "encoding.h"

// Timeout in seconds for program upload
#define TIMEOUT			1

#ifdef	SYNTHESIS
#define UART_DIVIDER	(CLK_FREQ / 16 / BAUDRATE) - 1 
#else
// Smaller values to allow a fast simulation of BootROM
#define UART_DIVIDER	1
#define CLK_FREQ		10000
#endif

int get_incoming_32b (){
	uint8_t tmp[4];
	uint32_t res;

	while(!uart_read(&tmp[0]));
	while(!uart_read(&tmp[1]));
	while(!uart_read(&tmp[2]));
	while(!uart_read(&tmp[3]));

	res = tmp[0] | (tmp[1] << 8) | (tmp[2] << 16) | (tmp[3] << 24);

	return res;
}

void main (){
	uint8_t		shamt = 0;
	uint32_t	signature = 0;
	uint8_t		tmp;
	uint8_t*	RAM_BASE = (uint8_t *) 0x80000000UL;

	set_uart_div(UART_DIVIDER); 
	print_uart("BOOTRDY\n");

    clear_csr(mcountinhibit, 1);
    write_csr(mcycle, 0);

	while (CLK_FREQ * TIMEOUT > read_csr(mcycle)){
		if (uart_read(&tmp)) {
			signature |= ((uint32_t)tmp) << shamt;
			shamt += 8;

			if (shamt == 32) {
				shamt = 0;
				if (signature == 0xB007BABE) break;
			}
		}
	}

	if (signature == 0xB007BABE) {
		uint32_t size = get_incoming_32b();
		print_uart("UPLDRDY");
		for (uint32_t i = 0; i < size; i++){
			while(!uart_read(&tmp));
			*RAM_BASE = tmp;
			RAM_BASE++;
		}
	}

	print_uart("JMP\n");
	__asm__ volatile(
        "li t0, 0x80000000;"
        "jr t0"
	);
}