/******************************/
/*                            */
/*   spike linker script      */
/*                            */
/******************************/


/*=============================
 * Memory region descriptions
 *=============================*/

MEMORY
{
  /* DRAM text VMA */
  DRAM_T_VMA (rx) : ORIGIN = 0x80000000, LENGTH = 16M

  /* DRAM data VMA */
  DRAM_D_VMA (rw) : ORIGIN = 0x81000000, LENGTH = 2032M /* 2048M - 16M */
}



/*=============================
 * Output section descriptions
 *=============================*/

SECTIONS
{
  /*----------------------------------
   * DRAM output sections
   *----------------------------------*/


  .text : 
  {
     *(.crtbegin) /* start code */
     *(.text.startup)
     *(.text)
     *(.text.*)
  } >DRAM_T_VMA 



  _bsg_data_start_addr =.;

  .data : 
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

    . = ALIGN(64);
    tohost = .;
    . = . + 4;

    . = ALIGN(64);
    fromhost = .;
    . = . + 4;
  } >DRAM_D_VMA 

  _bsg_dram_d_end_addr = . ;
  _bsg_dram_end_addr = . ;
  _bsg_data_end_addr = . ;

  _sp = 0xbffffffc; /* End of 1st ch of dram: 28-bit dram ch width */
  _end = _bsg_dram_end_addr; /* heap in dram */
}
