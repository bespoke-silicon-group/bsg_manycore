// testing entering remote interrupts during iterative floating point divider usage

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  // clear mip.remote
  li x1, 0x10000
  csrrc x0, mip, x1
  li x31, 0x3
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

  // setup for fdiv
  li x3, 0x16
  li x4, 0x7
  fcvt.s.w f0, x3
  fcvt.s.w f1, x4

  // issue a floating point divide instruction (1000/3)
  fdiv.s f2, f0, f1

  // send a remote interrupt to yourself (should get through immediately since backend is not stalled)
  li x1, bsg_tile_group_remote_interrupt_ptr(0,0)
  li x2, 1
  sw x2, 0(x1)

  // will fail if the remote interrupt did not fire
  fcvt.w.s x7, f2
  bne x7, x31, fail

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
