// testing entering remote interrupts during integer multiplier usage

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  // clear mip.remote
  li x1, 0x10000
  csrrc x0, mip, x1
  li x31, 0x2710
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

  // setup for imul
  li x3, 0x3e8
  li x4, 0x5

  // send yourself remote interrupt
  li x1, bsg_tile_group_remote_interrupt_ptr(0,0)
  li x2, 1
  sw x2, 0(x1)

  // issue a multiplication instruction (1000 * 5)
  mul x6, x3, x4

  // will fail if the remote interrupt did not fire
  bne x7, x31, fail

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
