OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
	SRAM (rwx) : ORIGIN = 0x80000000, LENGTH = 256K
}

SECTIONS
{
	. = ORIGIN(SRAM);

	.text : {
		*(.text.init)
		*(.text*)
	} > SRAM

	.rodata : {
		*(.rodata*)
	} > SRAM

	.data : {
		*(.data*)
	} > SRAM

	.bss (NOLOAD) : {
		*(.bss*)
		*(COMMON)
	} > SRAM

	. = ALIGN(16);
	PROVIDE(end = .);
	PROVIDE(_end = .);
	PROVIDE(__end = .);
	__stack_top = ORIGIN(SRAM) + LENGTH(SRAM);
}