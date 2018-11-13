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
  _bsg_data_start = . ;
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
  _bsg_data_end = .;
  /* text: test code section */
  /* SHX : Currently there is no exceptions allowed in bsg_manycore, so
   *       we don't want to wast the instruciton memory space, the first
   *       instuction address will start at zero
   */

  /* . = 0x100;  */
  . = 0x10000000      ;
  _bsg_dram_start = . ;
  .text : 
  {
    crt.o(.text)
    *(.text)
    *(.text.startup)
  }
  _bsg_dram_end = .  ;
}

