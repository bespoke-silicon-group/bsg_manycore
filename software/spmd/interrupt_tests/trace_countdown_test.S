// Author: Tommy
// testing entering trace interrupt and exiting..

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  j fail
_trace_interrupt:
  // clear mip.trace
  li x1, 0x20000
  csrrc x0, mip, x1
  mret

_start:
  bsg_asm_init_regfile

  // enable mstatus.MIE
  li x1, 0x8
  csrrw x0, mstatus, x1

  // enable mie.trace
  li x1, 0x20000
  csrrw x0, mie, x1

  // count down from 10
  li x2, 10

countdown_loop:
  beq x2, x0, pass
  addi x2, x2, -1
  j countdown_loop
  j fail



// returning from interrupt
pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
