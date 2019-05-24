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
  _sp = 0x1fff ;
  _bsg_data_start_addr = . ;

  /* data segment */
  .data : 
  { 
    bsg_manycore_lib.a:(.data*) 
  }
  .sdata : {
    _gp = . + 0x800;
    *bsg_manycore_lib.a:(.sdata .sdata.* .gnu.linkonce.s.* .srodata.cst16 .srodata.cst8 .srodata.cst4 .srodata.cst2 .srodata*)
  }

  /* bss segment */
  .sbss : {
    bsg_manycore_lib.a:(.sbss .sbss.* .gnu.linkonce.sb.* .scommon)
  }
  .bss : { 
    bsg_manycore_lib.a:(.bss*) 
  }

  /* thread-local data segment */
  .tdata :
  {
    _tls_data = .;
    bsg_manycore_lib.a:(.tdata)
  }
  .tbss :
  {
    bsg_manycore_lib.a:(.tbss)
  }
  .eh_frame : 
  { 
    bsg_manycore_lib.a:(.eh_frame) 
  }

  /* RISC-V 32 has a 4 byte word size */
  .striped.data ALIGN(bsg_group_size * 4): {
    _bsg_striped_data_start = . ;
    *(.striped.data)
  }

  _bsg_data_end_addr = . - SIZEOF(.striped.data) + (SIZEOF(.striped.data) / bsg_group_size);
  _bsg_bin_end_addr = .;
  /* End of uninitalized data segement */
  /* _bsg_data_end_addr = .; */
  ASSERT(_bsg_data_end_addr < 0x2000, "[ Error ] during linking, local dmem overflow, please check the dmem usage")
  
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
  .text 0x80000000 : AT ( _bsg_bin_end_addr ){
          *crt.o(.text)
          *(.text)
          *(.text.startup)
          *(.dram*)
          *(.rodata*) 
          *(.data*)
          *(.sdata .sdata.* .gnu.linkonce.s.* .srodata.cst16 .srodata.cst8 .srodata.cst4 .srodata.cst2 .srodata*)
          *(.sbss .sbss.* .gnu.linkonce.sb.* .scommon)
          *(.bss*)
          *(.eh_frame)
          *(.*)
        }
  _bsg_dram_end_addr = .  ;
}

