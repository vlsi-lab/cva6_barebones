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

#ifndef _SOC_GPIO_
#define _SOC_GPIO_

#include "regutils.h"

#define GPIO_BASE_ADDR 0x10001000

#define GPIO_DDR_REG_OFFSET 0x0
#define GPIO_ODR_REG_OFFSET 0x8
#define GPIO_IDR_REG_OFFSET 0x10

static inline void gpio_config(uint8_t ddr) {
	write_reg_u8(GPIO_BASE_ADDR + GPIO_DDR_REG_OFFSET, ddr);
}

static inline uint8_t gpio_read() {
	return read_reg_u8(GPIO_BASE_ADDR + GPIO_IDR_REG_OFFSET);
}

static inline void gpio_write(uint8_t odr) {
	write_reg_u8(GPIO_BASE_ADDR + GPIO_ODR_REG_OFFSET, odr);
}

static inline void gpio_config_pin(uint8_t pin, uint8_t output){
	if (pin > 7) return;
	uint8_t ddr = read_reg_u8(GPIO_BASE_ADDR + GPIO_DDR_REG_OFFSET);
	ddr &= ~(1u << pin);
	ddr |= (output & 0x1) << pin;
	write_reg_u8(GPIO_BASE_ADDR + GPIO_DDR_REG_OFFSET, ddr);
}

static inline uint8_t gpio_read_pin(uint8_t pin) {
	return (read_reg_u8(GPIO_BASE_ADDR + GPIO_IDR_REG_OFFSET) >> pin) & 0x1;
}

static inline void gpio_write_pin(uint8_t pin, uint8_t value){
	if (pin > 7) return;
	uint8_t odr = read_reg_u8(GPIO_BASE_ADDR + GPIO_ODR_REG_OFFSET);
	odr &= ~(1u << pin);
	odr |= (value & 0x1) << pin;
	write_reg_u8(GPIO_BASE_ADDR + GPIO_ODR_REG_OFFSET, odr);
}

#endif