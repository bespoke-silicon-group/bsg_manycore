// test to observe interaction between jalr mispredicts and trace interrupts
// A jalr mispredict happens when there is a call to a function. On a function return, the register (effectively a 1-entry RAS) correctly fetches the return address

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  j fail
_trace_interrupt:
  // clear mip.trace
  li x8, 0x20000
  csrrc x0, mip, x8
  addi x30, x30, 1
  mret

_start:
  bsg_asm_init_regfile

  // enable mstatus.MIE
  li x8, 0x8
  csrrw x0, mstatus, x8

  // Setup
  li x5, 10 // Loop variable

  // enable mie.trace
  li x8, 0x20000
  csrrw x0, mie, x8
  j loop

foo:
  // Store return address on stack
  addi sp, sp, -4
  sw x1, 0(sp)
  // Call function bar
  call bar
  // Reload address from the stack
  lw x1, 0(sp)
  addi sp, sp, 4
  // Return
  ret

loop:
  beq x5, x0, done
  call foo
  addi x5, x5, -1
  j loop

done:
  // Compare trace count
  li x31, 143
  bne x31, x30, fail
  // Compare incremented variable count
  li x31, 10
  bne x31, x6, fail
  j  pass

bar:
  // Add 1 to a register
  addi x6, x6, 1
  // Return
  ret

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop