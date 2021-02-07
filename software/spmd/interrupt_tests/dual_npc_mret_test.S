// stress testing the npc changes during an mret by making an interrupt pending at mret

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  j _remote_interrupt_handler
_trace_interrupt:
  // send a remote interrupt
  sw x4, 0(x3)

  // clear mip.trace
  li x1, 0x20000
  csrrc x0, mip, x1

  // keep remote interrupt pending
  nop

  mret

_remote_interrupt_handler:
  // clear mip.remote
  li x1, 0x10000
  csrrc x0, mip, x1

  // increment counter
  addi x31, x31, 1
  
  mret

_start:
  bsg_asm_init_regfile

  // enable mstatus.MIE
  li x1, 0x8
  csrrw x0, mstatus, x1

  // setup for a remote interrupt
  // Send a remote interrupt
  li x3, bsg_tile_group_remote_interrupt_ptr(0,0)
  li x4, 1

  // loop variable
  li x5, 10

  // enable mie.remote and mie.trace
  li x1, 0x30000
  csrrw x0, mie, x1

  // bunch of nops here since we don't really care what happens, we are only testing interrupt-mret behavior
loop:
  beq x5, x0, done 
  addi x5, x5, -1
  j loop

done:
  // even the following instruction gets traced so update the check accordingly
  li x30, 32
  bne x30, x31, fail

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop