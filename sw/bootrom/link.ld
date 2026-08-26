/* 
Copyright 2026 Federico Runco (federico.runco@gmail.com)
SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

Licensed under the Solderpad Hardware License v2.1 (the “License”); 
you may not use this file except in compliance with the License, or, 
at your option, the Apache License version 2.0. You may obtain a copy 
of the License at https://solderpad.org/licenses/SHL-2.1/

Unless required by applicable law or agreed to in writing, any work 
distributed under the License is distributed on an “AS IS” BASIS, WITHOUT 
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
License for the specific language governing permissions and limitations 
under the License.
*/

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    BROM (rx) : ORIGIN = 0x00010000, LENGTH = 64K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.init))
        *(.text*)
    } > BROM

    .rodata : {
        *(.rodata*)
        *(.srodata*)
    } > BROM

    .data : { 
        *(.data*) 
        *(.sdata*) 
    } > BROM

    .bss : { 
        *(.bss*) 
        *(.sbss*) 
        *(COMMON) 
    } > BROM

    . = ALIGN(16);
    PROVIDE(end = .);
    PROVIDE(_end = .);
    PROVIDE(__end = .);
}