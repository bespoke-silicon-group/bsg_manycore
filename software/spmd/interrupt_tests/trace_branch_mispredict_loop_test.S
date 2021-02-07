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
  li x3, 1

.org 4096
countdown_loop:
  beq x0, x2, pass
  beq x0, x0, loop1             // forward branch (predict not taken, but actually taken)
loop1:
  beq x0, x3, countdown_loop    // backward branch (predict taken, but not actually taken)
  addi x2, x2, -1
  j countdown_loop

// don't go here
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
