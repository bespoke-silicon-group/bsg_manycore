// Author: Tommy
// testing both trace and remote interrupt

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  j _remote_interrupt_handler
_trace_interrupt:
  // clear mip.trace
  li x1, 0x20000
  csrrc x0, mip, x1
  mret

_remote_interrupt_handler:
  // clear mip.remote
  li x1, 0x10000
  csrrc x0, mip, x1
  mret

_start:
  bsg_asm_init_regfile

  // enable mstatus.MIE
  li x1, 0x8
  csrrw x0, mstatus, x1

  // enable mie.trace
  li x1, 0x30000
  csrrw x0, mie, x1

  // count down from 10
  li x2, 10
  li x4, 1

.org 4096
countdown_loop:
  beq x0, x2, pass
  li x3, bsg_tile_group_remote_interrupt_ptr(0,0)
  sw x4, 0(x3)
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
