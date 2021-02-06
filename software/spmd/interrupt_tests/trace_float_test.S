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

  // count down from 10.0
  fcvt.s.w f0, x0
  li x2, 10
  fcvt.s.w f2, x2
  li x3, 1
  fcvt.s.w f3, x3
  li x4, 1


countdown_loop:
  feq.s x2, f2, f0
  beq x2, x4, pass
  fsub.s f2, f2, f3
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
