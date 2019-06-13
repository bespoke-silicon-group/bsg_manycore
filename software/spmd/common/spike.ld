OUTPUT_ARCH( "riscv" )

/*----------------------------------------------------------------------*/
/* Sections                                                             */
/*----------------------------------------------------------------------*/

SECTIONS
{
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

  _bsg_data_end_addr = . ;
  _bsg_dram_end_addr = . ;

  _sp = 0xfffffffc;
}
