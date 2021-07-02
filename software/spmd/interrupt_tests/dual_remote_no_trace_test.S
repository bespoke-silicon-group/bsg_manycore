// this test attempts to establish the priority of remote interrupts over trace interrupts and gives a way we can use remote interrupts to
// Even though tracing is enabled, we don't want to see PC traces

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl _start
_remote_interrupt:
  j _remote_interrupt_handler
_trace_interrupt:
  // clear mip.trace
  li x1, 0x20000
  csrrc x0, mip, x1
  addi t0, t0, 1
  mret

_remote_interrupt_handler:
  // clear mie.remote
  li x1, 0x10000
  csrrc x0, mip, x1

  // change MEPC to the next instruction (pseudo tracing)
  lw x30, 0(sp)
  beq x30, x15, t
nt:
  // send out a new remote interrupt; should be pending on exit
  sw x4, 0(x3) 
t: 
  addi sp, sp, 4
  csrrw x0, mepc, x30
  mret

_start:
  bsg_asm_init_regfile

  // enable mstatus.MIE
  li x1, 0x8
  csrrw x0, mstatus, x1

  // enable mie.remote
  li x1, 0x10000
  csrrw x0, mie, x1

  // Saving all remote targets on stack
  la x11, r1
  la x12, r2
  la x13, r3
  la x14, r4
  la x15, r5
  addi sp, sp, -20
  sw x11, 0(sp)
  sw x12, 4(sp)
  sw x13, 8(sp)
  sw x14, 12(sp)
  sw x15, 16(sp)

  // setup for a remote interrupt
  li x3, bsg_tile_group_remote_interrupt_ptr(0,0)
  li x4, 1
  sw x4, 0(x3)

  // enable mie.trace now
  li x1, 0x20000
  csrrs x0, mie, x1

  // trace interrupts should not be trigerred for these instructions
  addi t1, t1, 1
r1:
  addi t1, t1, 1
r2:
  addi t1, t1, 1
r3:
  addi t1, t1, 1
r4:
  addi t1, t1, 1
r5:
  // tracing would be valid from here
  li x4, 5
  // tracing shouldn't have been done before
  beq x4, t0, fail
  // first instance of the series of addi's above should be executed
  li x4, 1
  // t1 should not have been incremented at all
  bne x4, t1, fail

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop


