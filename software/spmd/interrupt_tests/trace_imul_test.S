// testing entering trace interrupts during integer multiplier usage

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

  li x3, 0x3e8
  li x4, 0x5
  li x5, 0x2

  // issue a multiplication instruction (1000 * 5)
  mul x6, x3, x4
  // multiplier dependency (not a real stall since multiplication is 1 cycle (uses fma), trace interrupt should fire as expected)
  mul x7, x6, x5

  li x31, 0x2710
  bne x7, x31, fail

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
