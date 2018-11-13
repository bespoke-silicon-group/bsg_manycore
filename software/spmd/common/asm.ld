OUTPUT_ARCH( "riscv" )
SECTIONS
{

  . = 0x1000;
  _bsg_data_start = .  ;
  /* data segment */
  .data : { *(.data) }

  .bss : { *(.bss) }

  _bsg_data_end = .;

  . = 0x10000000        ;
  _bsg_dram_start = .   ;
  .text : { *(.text) }
  _bsg_dram_end = .     ;
}

