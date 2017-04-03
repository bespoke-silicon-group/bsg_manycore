OUTPUT_ARCH( "riscv" )
SECTIONS
{
  .text : { *(.text) }
  _bsg_text_end = .;

  . = 0x1000;
  /* data segment */
  .data : { *(.data) }

  .bss : { *(.bss) }

   _end = .;
}

