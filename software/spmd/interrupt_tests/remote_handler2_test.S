// testing behavior of icache misses in the trace interrupt handler (make a function call to a different region but mret from same region)

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  // clear mip.remote
  li x1, 0x10000
  csrrc x0, mip, x1
  call _count_remote_interrupt
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

  // send yourself a remote interrupt
  li x1, bsg_tile_group_remote_interrupt_ptr(0,0)
  li x2, 1
  sw x2, 0(x1)

  // wait for interrupt
  nop
  li x31, 0xbeef
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

// force an icache miss
.org 4096
_count_remote_interrupt:
  li x30, 0xbeef
  ret