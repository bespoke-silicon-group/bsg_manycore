OUTPUT_ARCH( "riscv" )
SECTIONS
{

  . = 0x1000;
  _bsg_data_start_addr = .  ;
  /* data segment */
  .data : { *(.data) }

  .bss : { *(.bss) }

  _bsg_data_end_addr = .;

  /*The DRAM content is start at zero, 
   *The instruction fetch unit and the loader will send address that 
   *is mapped to the actual dram module.
   */
  _bsg_dram_start_addr = 0x0;
  OVERLAY 0x0 : 
  {
        .text 
        {
          *(.text)
        }
  }
  _bsg_dram_end_addr = .  ;
}

