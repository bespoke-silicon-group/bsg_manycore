// testing behavior of icache misses in the trace interrupt handler (make a function call to a different region but mret from same region)

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  j _remote_interrupt_handler
_trace_interrupt:
  // clear mip.trace
  li x1, 0x20000
  csrrc x0, mip, x1
  call _count_trace_interrupt
  mret

_remote_interrupt_handler:
  // clear mip.remote
  li x1, 0x10000
  csrrc x0, mip, x1
  j _count_remote_interrupt

_start:
  bsg_asm_init_regfile

  // enable mstatus.MIE
  li x1, 0x8
  csrrw x0, mstatus, x1

  // enable mie.remote
  li x1, 0x30000
  csrrw x0, mie, x1

  // send yourself a remote interrupt
  li x3, bsg_tile_group_remote_interrupt_ptr(0,0)
  li x4, 1
  sw x4, 0(x3)

  li x31, 0xbeef
  bne x30, x31, fail
  li x31, 0xdead
  bne x29, x31, fail

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
  li x29, 0xdead
  mret

.org 4096*2
_count_trace_interrupt:
  li x30, 0xbeef
  ret