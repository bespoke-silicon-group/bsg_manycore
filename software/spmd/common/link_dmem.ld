/******************************/
/*                            */
/*   Manycore linker script   */
/*                            */
/******************************/

/* This link script places data sections in dmem
 * by default. Text sections are placed in dram.
 *
 * Data in sections ".rodata.*" and ".dram"
 * is placed in the DRAM.
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
    *(.data) 
    *(.data*) 
  } >DMEM_VMA

  .sdata.dmem :
  AT(LOADADDR(.data.dmem) + SIZEOF(.data.dmem)) 
  {
    _gp = . + 0x800;
    *(.srodata.cst16) 
    *(.srodata.cst8)
    *(.srodata.cst4)
    *(.srodata.cst2)
    *(.srodata*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
  } >DMEM_VMA


  /* bss segment */
  .sbss.dmem : 
  AT(LOADADDR(.sdata.dmem) + SIZEOF(.sdata.dmem)) 
  {
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
  } >DMEM_VMA 

  .bss.dmem : 
  AT(LOADADDR(.sbss.dmem) + SIZEOF(.sbss.dmem)) 
  { 
    *(.bss) 
    *(.bss*) 
  } >DMEM_VMA 


  /* thread-local data segment */
  .tdata.dmem : 
  AT(LOADADDR(.bss.dmem) + SIZEOF(.bss.dmem)) 
  {
    _tls_data = .;
    *(.tdata)
    *(.tdata*)
  } >DMEM_VMA 

  .tbss.dmem : 
  AT(LOADADDR(.tdata.dmem) + SIZEOF(.tdata.dmem)) 
  {
    *(.tbss)
    *(.tbss*)
  } >DMEM_VMA 


  /* read-only data */
  .rodata.dmem :
  AT(LOADADDR(.tbss.dmem) + SIZEOF(.tbss.dmem)) 
  { 
    *(.rodata) 
  } >DMEM_VMA 


  .eh_frame.dmem : 
  AT(LOADADDR(.rodata.dmem) + SIZEOF(.rodata.dmem)) 
  { 
    *(.eh_frame) 
    *(.eh_frame*) 
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

  _sp = _bsg_elf_stack_ptr;

  ASSERT(_bsg_data_end_addr < 0x2000, 
         "[ Error ] during linking, local dmem overflow, please check the dmem usage"
        ) 




  /*----------------------------------
   * DRAM output sections
   *----------------------------------*/


  /* I-EVA backing storage sections should end with .i.dram */
  . = 0x0;                                    /* I-EVAs start address */
  _bsg_dram_t_start_addr = _dram_t_lma_start; /* _bsg_dram_i_start_addr and _bsg_dram_i_end_addr 
                                                 are the DRAM NPAs required by loader 
                                               */

  .text.dram : 
  AT(_dram_t_lma_start) 
  {
     *(.crtbegin) /* start code */
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

  .data.dram : 
  AT(_dram_d_lma_start) 
  {
    _dram_rodata = .;
    *(.rodata*) 

    _dram_dram = .;
    *(.dram)
    . = ALIGN(4);
  } >DRAM_D_VMA 

  _bsg_dram_d_end_addr = . ;
  _bsg_dram_end_addr = . ;
  _end = _bsg_dram_end_addr; /* heap in dram */
}
