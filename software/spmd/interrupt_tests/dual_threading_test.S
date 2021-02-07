// this program creates a tiny threading package. The threads communicate with each other using remote interruts.
// A remote interrupt switches the MEPC register in the handler and moves to the other thread. 

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// Register usage
// t0 - Scratch pad - useful for loading masks and other things into CSRs
// t1, t2 - Registers used for sending remote interrupts
// t3, t4, t5, t6 - registers used for context switching
// s2, s3, s4 - Registers used by thread 1 and 2

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

  // Read current MEPC
  csrrw t6, mepc, x0

  // Read the stack for next thread info (GPR + MEPC)
  lw t5, 8(sp)
  lw t4, 4(sp)
  lw t3, 0(sp)
  // Write current thread info to stack
  sw s2, 0(sp)
  sw s3, 4(sp)
  sw t6, 8(sp)
  // Restore next thread's state
  add s2, t3, x0
  add s3, t4, x0

  // Write new MEPC
  csrrw x0, mepc, t5

  mret 

_start:
  bsg_asm_init_regfile

.org 2048
  // enable mstatus.MIE
  li x1, 0x8
  csrrw x0, mstatus, x1

  // Setup
  // thread 1
  li s2, 10 // loop variable

  // thread 2
  // Write contents to stack
  addi sp, sp, -12
  li t3, 10 // loop variable
  li t4, 0  // result
  la t5, t2_entry // start address for thread 2
  // Write thread 2 values to stack
  sw t3, 0(sp)
  sw t4, 4(sp)
  sw t5, 8(sp)

  // remote interrupt
  li t1, bsg_tile_group_remote_interrupt_ptr(0,0)
  li t2, 1

  // enable mie.remote and mie.trace
  li x1, 0x30000
  csrrw x0, mie, x1

// t1 is a +10 loop
t1_entry:
  beq x0, s2, t1_done
  addi s3, s3, 10
  addi s2, s2, -1
  sw t2, 0(t1)
  nop
  nop
  j t1_entry

t1_done:
  li s4, 100
  beq s4, s3, pass
  j fail

.org 4096
// t2 is a +20 loop
t2_entry:
  beq x0, s2, t2_done
  addi s3, s3, 20
  addi s2, s2, -1
  sw t2, 0(t1)
  nop
  nop
  j t2_entry

t2_done:
  li s4, 200
  beq s4, s3, pass
  j fail

.org 6144
pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop