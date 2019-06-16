/******************************/
/*                            */
/*   Manycore linker script   */
/*                            */
/******************************/

/* This link script places data section in dram
 * by default. Text sections are places in dram.
 *
 */


/* Constants */
PROVIDE(_dmem_lma_start   = 0x00001000);
PROVIDE(_dram_t_lma_start = 0x80000000);
PROVIDE(_dram_d_lma_start = 0x81000000);



/*=============================
 * Memory region descriptions
 *=============================*/

MEMORY
{
  /* Local memory VMA */
  DMEM_VMA (rw) : ORIGIN = 0x1000, LENGTH = 4K

  /* DRAM text VMA */
  DRAM_T_VMA (rx) : ORIGIN = 0x0, LENGTH = 16M

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


  /* I-EVA backing storage sections should end with .i.dram */
  _bsg_dram_t_start_addr = _dram_t_lma_start; /* _bsg_dram_i_start_addr and _bsg_dram_i_end_addr 
                                                 are the DRAM NPAs required by loader 
                                               */

  .text.dram : 
  AT(_dram_t_lma_start) 
  {
     *crt.o(.text)
     *(.text)
     *(.text.startup)
     *(.text.*)
  } >DRAM_T_VMA 

  _bsg_dram_t_end_addr = 0x80000000 + .; /* added 0x80... becuase location counter would
                                            VMA's of text section starts with 0x0 but loader
                                            need NPAs of text section in the dram
                                          */

  
  /* D-EVA sections in dram should end with .d.dram */
  . = 0x81000000;             /* DRAM data's VMA start address */
  _bsg_dram_d_start_addr = .; /* _bsg_dram_d_start_addr and _bsg_dram_d_end_addr 
                                are the DRAM NPAs required by loader 
                              */
  _bsg_data_start_addr =.;

  .data.dram : 
  AT(_dram_d_lma_start) 
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
  } >DRAM_D_VMA 

  _bsg_dram_d_end_addr = . ;
  _bsg_dram_end_addr = . ;
  _bsg_data_end_addr = . ;

  _sp = 0xbffffffc; /* End of 1st ch of dram: 28-bit dram ch width */
}
