// testing behavior of icache misses in the trace interrupt handler (mret from a different region)

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  j fail
_trace_interrupt:
  // clear mip.trace
  li x1, 0x20000
  csrrc x0, mip, x1
  j _count_trace_interrupt

_start:
  bsg_asm_init_regfile

  // enable mstatus.MIE
  li x1, 0x8
  csrrw x0, mstatus, x1

  // enable mie.trace
  li x1, 0x20000
  csrrw x0, mie, x1

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
_count_trace_interrupt:
  li x30, 0xbeef
  mret