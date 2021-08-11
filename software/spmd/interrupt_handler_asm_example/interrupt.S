#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl mydata
  
.section .text.interrupt, "a"
_remote_interrupt:
  j _remote_interrupt_handler

_trace_interrupt:
  bsg_asm_fail(IO_X_INDEX, 0);
_fail_loop:
  j _fail_loop

_remote_interrupt_handler:
  // save two registers to DMEM
  sw t0, 0(x0)
  sw t1, 4(x0)
  // turn off remote pending bit
  li t0, 0x10000
  csrrc x0, mip, t0
  // write beef to mydata
  la t0, mydata
  li t1, 0xbeef
  sw t1, 0(t0)  
  fence
  // restore t0, t1
  lw t0, 0(x0)
  lw t1, 4(x0)
  // return to mepc
  mret
