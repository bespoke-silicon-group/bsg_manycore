// testing entering trace interrupts during iterative floating point divider usage

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

  // setup for fdiv
  li x3, 0x16
  li x4, 0x7
  li x5, 0x8
  li x6, 0x3
  fcvt.s.w f0, x3
  fcvt.s.w f1, x4
  fcvt.s.w f2, x5
  fcvt.s.w f3, x6

  // issue a floating point divide instruction (1000/3)
  fdiv.s f3, f0, f1
  // divider busy stall; trace interrupt should bot fire until first division completes
  fdiv.s f6, f2, f3

  // decode dependency stall; trace interrupt should not fire until divider completes
  fcvt.w.s x7, f6
  li x31, 0x3
  bne x7, x31, fail

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
