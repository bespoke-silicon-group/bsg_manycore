/******************************/
/*                            */
/*   Manycore linker script   */
/*                            */
/******************************/


/*=============================
 * Memory region descriptions
 *=============================*/

MEMORY
{
  /*-------------------------------------
   * Virtual Memory Address (VMA) regions
   *-------------------------------------*/

  /* Local memory VMA */
  DMEM_VMA (rw) : ORIGIN = 0x1000, LENGTH = 4K

  /* DRAM text VMA */
  DRAM_T_VMA (rx) : ORIGIN = 0x0, LENGTH = 16M

  /* DRAM data VMA */
  DRAM_D_VMA (rw) : ORIGIN = 0x81000000, LENGTH = 2032M /* 2048M - 16M */


  /*----------------------------------
   * Load Memory Address (LMA) regions
   *----------------------------------*/

  /* Local memory LMA */
  DMEM_LMA (rw) : ORIGIN = 0x1000, LENGTH = 4K

  /* DRAM text LMA */
  DRAM_T_LMA (rx) : ORIGIN = 0x0, LENGTH = 16M

  /* DRAM data LMA */
  DRAM_D_LMA (rw): ORIGIN = 0x01000000, LENGTH = 2032M
}


/*=============================
 * Program header declarations
 *=============================*/

PHDRS
{
  dmem   PT_LOAD ;
  dram_t PT_LOAD ;
  dram_d PT_LOAD ;
}


/*=============================
 * Output section descriptions
 *=============================*/

SECTIONS
{
  /* _bsg_data_start_addr and _bsg_data_end_addr are DMEM LMAs required by loader */
  _bsg_data_start_addr = 0x1000 ;

  /* data segment */
  .data : { 
    *(.data) 
  } >DMEM_VMA AT>DMEM_LMA : dmem

  .sdata : {
    _gp = . + 0x800;
    *(.srodata.cst16) *(.srodata.cst8) *(.srodata.cst4) *(.srodata.cst2) *(.srodata*)
    *(.sdata .sdata.* .gnu.linkonce.s.*)
  } >DMEM_VMA AT>DMEM_LMA


  /* bss segment */
  .sbss : {
    *(.sbss .sbss.* .gnu.linkonce.sb.*)
    *(.scommon)
  } >DMEM_VMA AT>DMEM_LMA

  .bss : { 
    *(.bss) 
  } >DMEM_VMA AT>DMEM_LMA


  /* thread-local data segment */
  .tdata : {
    _tls_data = .;
    *(.tdata)
    *(.tdata*)
  } >DMEM_VMA AT>DMEM_LMA

  .tbss : {
    *(.tbss)
    *(.tbss*)
  } >DMEM_VMA AT>DMEM_LMA


  /* read-only data */
  .rodata : { 
    *(.rodata) 
    *(.rodata*) 
  } >DMEM_VMA AT>DMEM_LMA


  .eh_frame : { 
    *(.eh_frame) 
    *(.eh_frame*) 
  } >DMEM_VMA AT>DMEM_LMA

  
  /* striped data */
  /* RISC-V 32 has a 4 byte word size */
  .striped.data ALIGN(bsg_group_size * 4): {
    _bsg_striped_data_start = . ;
    *(.striped.data)
  } >DMEM_VMA AT>DMEM_LMA

  _bsg_data_end_addr = . - SIZEOF(.striped.data) + (SIZEOF(.striped.data) / bsg_group_size);

  _sp = 0x1fff;

  ASSERT(_bsg_data_end_addr < 0x2000, "[ Error ] during linking, local dmem overflow, please check the dmem usage")
  
  /* _bsg_dram_start_addr and _bsg_dram_end_addr are the DRAM LMAs required by loader */
  _bsg_dram_start_addr = 0x80000000;

  .text : {
     *crt.o(.text)
     *(.text)
     *(.text.startup)
  } >DRAM_T_VMA AT>DRAM_T_LMA : dram_t

  .data.dram : {
    *(.dram)
  } >DRAM_D_VMA AT>DRAM_D_LMA : dram_d

  _bsg_dram_end_addr = 0x81000000 + SIZEOF(.data.dram) ;
}
