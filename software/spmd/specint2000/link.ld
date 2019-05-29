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
  _bsg_data_start_addr = 0x1000;
  _bsg_data_end_addr = .;
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
  .text 0x80000000 : {
          *crt.o(.text)
          *(.text)
          *(.text.startup)
          *(.dram*)
          *(.rodata*) 
          *(.data*)
          _gp = .;
          *(.sdata .sdata.* .gnu.linkonce.s.* .srodata.cst16 .srodata.cst8 .srodata.cst4 .srodata.cst2 .srodata*)
          *(.sbss .sbss.* .gnu.linkonce.sb.* .scommon)
          *(.bss*)
          *(.eh_frame)
          *(.*)
        }
  _bsg_dram_end_addr = .  ;

  . = 0x80200000;
  _sp = . - 4;
}

