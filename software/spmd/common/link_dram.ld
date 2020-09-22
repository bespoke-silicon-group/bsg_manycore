/******************************/
/*                            */
/*   Manycore linker script   */
/*                            */
/******************************/

/* This link script places data section in dram
 * by default. Text sections are places in dram.
 *
 * Data in bsg_manycore_lib.a & .dmem is placed in dmem. 
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
  DRAM_D_VMA (rw) : ORIGIN = 0x81000000, LENGTH = (_bsg_elf_dram_size - 16M)
}


/*=============================
 * Output section descriptions
 *=============================*/

SECTIONS
{

  /*----------------------------------
   * DMEM output sections
   *----------------------------------*/


  /* _bsg_data_start_addr and _bsg_data_end_addr are DMEM EPAs required by loader */
  _bsg_data_start_addr = 0x1000 ;

  /* data segment */
  .data.dmem : 
  AT(_dmem_lma_start) 
  { 
    *(.dmem)
    *bsg_manycore_lib.a:(.data) 
    *bsg_manycore_lib.a:(.data*) 
  } >DMEM_VMA

  .sdata.dmem :
  AT(LOADADDR(.data.dmem) + SIZEOF(.data.dmem)) 
  {
    *bsg_manycore_lib.a:(.srodata.cst16) 
    *bsg_manycore_lib.a:(.srodata.cst8)
    *bsg_manycore_lib.a:(.srodata.cst4)
    *bsg_manycore_lib.a:(.srodata.cst2)
    *bsg_manycore_lib.a:(.srodata*)
    *bsg_manycore_lib.a:(.sdata .sdata.* .gnu.linkonce.s.*)
  } >DMEM_VMA


  /* bss segment */
  .sbss.dmem : 
  AT(LOADADDR(.sdata.dmem) + SIZEOF(.sdata.dmem)) 
  {
    *bsg_manycore_lib.a:(.sbss .sbss.* .gnu.linkonce.sb.*)
    *bsg_manycore_lib.a:(.scommon)
  } >DMEM_VMA 

  .bss.dmem : 
  AT(LOADADDR(.sbss.dmem) + SIZEOF(.sbss.dmem)) 
  { 
    *bsg_manycore_lib.a:(.bss) 
    *bsg_manycore_lib.a:(.bss*) 
  } >DMEM_VMA 


  /* thread-local data segment */
  .tdata.dmem : 
  AT(LOADADDR(.bss.dmem) + SIZEOF(.bss.dmem)) 
  {
    _tls_data = .;
    *bsg_manycore_lib.a:(.tdata)
    *bsg_manycore_lib.a:(.tdata*)
  } >DMEM_VMA 

  .tbss.dmem : 
  AT(LOADADDR(.tdata.dmem) + SIZEOF(.tdata.dmem)) 
  {
    *bsg_manycore_lib.a:(.tbss)
    *bsg_manycore_lib.a:(.tbss*)
  } >DMEM_VMA 


  /* read-only data */
  .rodata.dmem :
  AT(LOADADDR(.tbss.dmem) + SIZEOF(.tbss.dmem)) 
  { 
    *bsg_manycore_lib.a:(.rodata) 
  } >DMEM_VMA 


  .eh_frame.dmem : 
  AT(LOADADDR(.rodata.dmem) + SIZEOF(.rodata.dmem)) 
  { 
    *bsg_manycore_lib.a:(.eh_frame) 
    *bsg_manycore_lib.a:(.eh_frame*) 
  } >DMEM_VMA 

  
  /* striped data */
  /* RISC-V 32 has a 4 byte word size */
  .striped.data.dmem ALIGN(bsg_group_size * 4) : 
  AT(LOADADDR(.eh_frame.dmem) + SIZEOF(.eh_frame.dmem)) 
  {
    _bsg_striped_data_start = . ;
    *(.striped.data)
  } >DMEM_VMA 

  _bsg_data_end_addr = . - SIZEOF(.striped.data.dmem) 
                         + (SIZEOF(.striped.data.dmem) / bsg_group_size);

  ASSERT(_bsg_data_end_addr < 0x2000, 
         "[ Error ] during linking, local dmem overflow, please check the dmem usage"
        ) 




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
     *(.crtbegin)
     *(.text.startup)
     *(.text)
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

    . = ALIGN(4);
  } >DRAM_D_VMA 

  _bsg_dram_d_end_addr = . ;
  _bsg_dram_end_addr = . ;

  _sp = _bsg_elf_stack_ptr;
}
