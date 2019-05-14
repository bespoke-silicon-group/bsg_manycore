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

  /* Pin down memory location for __bsg_x/y, __bsg_grp_org_x/y, __bsg_id, __bsg_grid_dim_x/y, and __bsg_tile_group_id_x/y symbols. */
  __bsg_x = . + 0xEDC;
  __bsg_y = . + 0xEE0;
  __bsg_grp_org_x = . + 0xEE4;
  __bsg_grp_org_y = . + 0xEE8;
  __bsg_id = . + 0xEEC;
  __bsg_grid_dim_x = . + 0xEF0;
  __bsg_grid_dim_y = . + 0xEF4;
  __bsg_tile_group_id_x = . + 0xEF8;
  __bsg_tile_group_id_y = . + 0xEFC;

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
          crt.o(.text)
          *(.text)
          *(.text.startup)
          *(.rodata*) 
          *(.dram)
        }
  _bsg_dram_end_addr = .  ;
}

