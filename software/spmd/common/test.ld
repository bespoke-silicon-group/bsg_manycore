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

group_size = 64;

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
  .rodata : { *(.rodata) }
  .eh_frame : { *(.eh_frame) }
  .striped.data ALIGN(group_size * 4): {
    _striped_data_start = . ;
    *(.striped.data)
  }

  /* End of uninitalized data segement */
  _bsg_data_end_addr = .;
  ASSERT(_bsg_data_end_addr - (SIZEOF(.striped.data) / group_size) < 0x2000, "[ Error ] during linking, local dmem overflow, please check the dmem usage")
  
  /*The DRAM content is start at zero, 
   *The instruction fetch unit and the loader will send address that 
   *is mapped to the actual dram module.
   
   * FIXME: We set the phsical address to _bsg_data_end_addr, but this is just 
   * a placehold address to prevent the linker from complaining about the overlapped
   * physical address with .data section.
   *
   * The objcopy program will dump this section with @[pysical address] notation, which tells
   * the verilog loader where to place the data.
   *
   * Ideally the physicall address should be 0x8000_0000, which is the DRAM address used in manycore 
   * program, but the system verilog $readmemh() just can not read from such large address... 
   * 
   * Instead we just use a faked physical address and assumpt the phiscal address is aslo zero in the loader
   */
  _bsg_dram_start_addr = 0x80000000;
  .text 0x80000000 : AT ( _bsg_data_end_addr ){
          crt.o(.text)
          *(.text)
          *(.text.startup)
          *(.rodata*) 
          *(.dram*)
        }
  _bsg_dram_end_addr = .  ;
}

