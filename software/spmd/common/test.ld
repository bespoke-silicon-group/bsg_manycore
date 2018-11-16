/*======================================================================*/
/* Proxy kernel linker script                                           */
/*======================================================================*/
/* This is the linker script used when building the proxy kernel. */

/*----------------------------------------------------------------------*/
/* Setup                                                                */
/*----------------------------------------------------------------------*/

/* The OUTPUT_ARCH command specifies the machine architecture where the
   argument is one of the names used in the BFD library. More
   specifically one of the entires in bfd/cpu-mips.c */

OUTPUT_ARCH( "riscv" )

/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/

SECTIONS
{
  /* beginning of data memory; set by imem size and bank conflict concerns */
  . = 0x1000;
  _bsg_data_start_addr = . ;
  /* data segment */
  .data : { *(.data) }

  .sdata : {
    _gp = . + 0x800;
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
  }

  /* bss segment */
  .sbss : {
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
  }
  .bss : { *(.bss) }

  /* thread-local data segment */
  .tdata :
  {
    _tls_data = .;
    crt.o(.tdata.begin)
    *(.tdata)
    crt.o(.tdata.end)
  }
  .tbss :
  {
    *(.tbss)
    crt.o(.tbss.end)
  }

  /* End of uninitalized data segement */
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
          crt.o(.text)
          *(.text)
          *(.text.startup)
        }
  }
  _bsg_dram_end_addr = .  ;
}

