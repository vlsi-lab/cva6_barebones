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

#ifndef _SOC_UART_
#define _SOC_UART_

#include "regutils.h"

#ifndef BOOTROM
#include <stdint.h>
#endif

#define UART_BASE_ADDR 0x10000000

#define UART_TX_DATA_REG_OFFSET 0x0
#define UART_RX_DATA_REG_OFFSET 0x8
#define UART_CSREG_REG_OFFSET 0x10
#define UART_DIVIDER_REG_OFFSET 0x18
#define UART_CSREG_BUSY_BIT 0
#define UART_CSREG_START_BIT 1
#define UART_CSREG_EMPTY_BIT 2


int uart_read(uint8_t *res)
{
    if((read_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET) >> UART_CSREG_EMPTY_BIT) & 0x1)
        return 0;

    *res = read_reg_u8(UART_BASE_ADDR + UART_RX_DATA_REG_OFFSET);
    return 1;
}

static inline void uart_putchar(char c) {
	while ((read_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET) >> UART_CSREG_BUSY_BIT) & 0x1);
	write_reg_u8(UART_BASE_ADDR + UART_TX_DATA_REG_OFFSET, (uint8_t) c);
	write_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET, 1 << UART_CSREG_START_BIT);
	while ( ! ((read_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET) >> UART_CSREG_BUSY_BIT) & 0x1 ));
	write_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET, 0 << UART_CSREG_START_BIT);
	while ((read_reg_u8(UART_BASE_ADDR + UART_CSREG_REG_OFFSET) >> UART_CSREG_BUSY_BIT) & 0x1);
}

void uart_print_byte(uint8_t byte)
{
    uint8_t c[2];
    uint8_t mapping [16] = {'0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F'};
    c[0] = mapping[byte & 0xf];
    c[1] = mapping[(byte >> 4) & 0xf];
    uart_putchar(c[1]);
    uart_putchar(c[0]);
}

static void print_uart(const char *str)
{
    const char *cur = &str[0];
    while (*cur != '\0')
    {
        uart_putchar((uint8_t)*cur);
        ++cur;
    }
}

static void set_uart_div (uint64_t div) {
    volatile uint64_t *loc_addr = (volatile uint64_t *) (UART_BASE_ADDR + UART_DIVIDER_REG_OFFSET);
    *loc_addr = div;
}

// Lightweight unsigned decimal printer. Prefer this over the sprintf-based
// printf() macro below when code size matters: the newlib sprintf machinery
// pulls in ~45 KB of formatting code, which does not fit in the default 64 KB
// SRAM for larger workloads (e.g. ML-KEM-512).
static void print_uart_dec(unsigned int value)
{
    char buf[10]; // 2^32-1 == 4294967295 -> 10 digits
    int i = 0;

    if (value == 0) {
        uart_putchar('0');
        return;
    }

    while (value > 0) {
        buf[i++] = (char)('0' + (value % 10));
        value /= 10;
    }
    while (i > 0)
        uart_putchar(buf[--i]);
}

#ifndef BOOTROM
#define printf(...) do { \
        char text[1024]; \
        sprintf(text, __VA_ARGS__); \
        print_uart(text); \
} while (0)
#endif

#endif