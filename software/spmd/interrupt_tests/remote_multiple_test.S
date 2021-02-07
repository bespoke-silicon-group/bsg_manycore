// Testing behaviour for a stream of remote interrupts (we expect the interrupts to override each other)

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  // clear mip.remote
  li x1, 0x10000
  csrrc x0, mip, x1
  addi x30, x30, 1
  mret
_trace_interrupt:
  j fail

_start:
  bsg_asm_init_regfile

  // enable mstatus.MIE
  li x1, 0x8
  csrrw x0, mstatus, x1

  // enable mie.remote
  li x1, 0x10000
  csrrw x0, mie, x1

  // count down from 4
  li x2, 4
  // setup for remote interrupts
  li x3, bsg_tile_group_remote_interrupt_ptr(0,0)
  li x4, 1

countdown_loop:
  beq x0, x2, check
  // send 4 back to back interrupts. Only 1 should be accepted
  sw x4, 0(x3)
  sw x4, 0(x3)
  sw x4, 0(x3)
  sw x4, 0(x3)
  addi x2, x2, -1
  j countdown_loop

  // don't go here
  j fail

check:
  li x31, 4
  bne x30, x31, fail

// returning from interrupt
pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
