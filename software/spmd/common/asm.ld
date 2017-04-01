OUTPUT_ARCH( "riscv" )
SECTIONS
{
  .text : { *(.text) }

  . = 0x1000;
  /* data segment */
  .data : { *(.data) }

  .bss : { *(.bss) }

   _end = .;
}

