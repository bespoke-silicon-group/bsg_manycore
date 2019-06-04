OUTPUT_ARCH( "riscv" )

/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/

SECTIONS
{
  .text 0x80000000: 
  {
     *crt.o(.text)
     *(.text)
     *(.text.startup)
     *(.text.*)
  } 

  
  .data 0x81000000: 
  {
    _dram_rodata = .;
    *(.rodata*) 

    _dram_dram = .;
    *(.dram)

    _dram_data = .;
    *(.data*)

    _dram_sdata = .;
    _gp = .;
    *(.sdata .sdata.* .gnu.linkonce.s.* .srodata.cst16 .srodata.cst8 .srodata.cst4 .srodata.cst2 .srodata*)

    _dram_sbss = .;
    *(.sbss .sbss.* .gnu.linkonce.sb.* .scommon)

    _dram_bss = .;
    *(.bss*)

    _dram_eh_frame = .;
    *(.eh_frame)

    _dram_misc = .;
    *(.*)
  } 

  _bsg_data_end_addr = . ;
  _bsg_dram_end_addr = . ;

  _sp = 0xbffffffc;
}
