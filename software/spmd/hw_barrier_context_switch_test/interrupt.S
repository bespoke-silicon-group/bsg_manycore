// each thread has a dedicated space in DRAM for thread context.
// __thread_data_block stores the entire 4KB DMEM content. 
// __thread_context_block stores the register file content, and other architectural states (barrier states).
// There are arrays of these blocks in DRAM for each tile's threads, which can be indexed by a combination of __bsg_id and __thread_id.
// When the tile receives a remote interrupt, it saves the current thread's context, and restores the next thread's context,
// and resumes the execution of the next thread by calling mret.


#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"


.globl __bsg_id
.globl __thread_id
.globl _thread_data_block
.globl _thread_context_block
.globl amoadd_lock
.globl amoadd_alarm



.section .text.interrupt, "a"
_remote_interrupt:
  j _remote_interrupt_handler

_trace_interrupt:
  bsg_asm_fail(IO_X_INDEX,0);
fail_loop:
  j fail_loop


_remote_interrupt_handler:
  // wait for outstanding remote loads to finish
  fence
  // save two registers to the reserved spot in DMEM
  sw t0, 0(x0)
  sw t1, 4(x0)
  // turn off remote pending bit
  li t0, 0x10000
  csrrc x0, mip, t0

  // calculate its thread context block addr
  la t0, __bsg_id
  lw t0, 0(t0)
  li t1, NUM_THREAD
  mul t0, t0, t1
  la t1, __thread_id
  lw t1, 0(t1)
  add t0, t0, t1
  li t1, 256
  mul t0, t0, t1
  la t1, _thread_context_block
  add t0, t0, t1 // t0 = thread context block addr

  // save its context (regfile)
  sw x1, 4(t0)
  sw x2, 8(t0)
  sw x3, 12(t0)
  sw x4, 16(t0)
  sw x7, 28(t0)
  sw x8, 32(t0)
  sw x9, 36(t0)
  sw x10, 40(t0)
  sw x11, 44(t0)
  sw x12, 48(t0)
  sw x13, 52(t0)
  sw x14, 56(t0)
  sw x15, 60(t0)
  sw x16, 64(t0)
  sw x17, 68(t0)
  sw x18, 72(t0)
  sw x19, 76(t0)
  sw x20, 80(t0)
  sw x21, 84(t0)
  sw x22, 88(t0)
  sw x23, 92(t0)
  sw x24, 96(t0)
  sw x25, 100(t0)
  sw x26, 104(t0)
  sw x27, 108(t0)
  sw x28, 112(t0)
  sw x29, 116(t0)
  sw x30, 120(t0)
  sw x31, 124(t0)
  mv s0, t0   // move to s0
  lw t0, 0(x0)
  lw t1, 4(x0)
  sw t0, 20(s0)
  sw t1, 24(s0)

  // save its mepc
  csrr t0, mepc
  sw t0, 132(s0)

  // join amoadd barrier
  la a0, amoadd_lock
  la a1, amoadd_alarm
  jal bsg_barrier_amoadd
  
  // save DMEM context
  // by this time, there should be no remote store in flight.
  // calculate its thread data block addr.
  la t0, __bsg_id
  lw t0, 0(t0)
  li t1, NUM_THREAD
  mul t0, t0, t1
  la t1, __thread_id
  lw t1, 0(t1)
  add t0, t0, t1
  li t1, 4096
  mul t0, t0, t1
  la t1, _thread_data_block
  add t0, t0, t1 // t0 = curr thread data block addr

  li t1, 0
  li t2, 4096
save_thread_data_context_loop:  
  lw t3, 0(t1)
  sw t3, 0(t0)
  addi t0, t0, 4
  addi t1, t1, 4
  bne t1, t2, save_thread_data_context_loop

  // check if there is hw barrier in progress
  csrr t0, BAR_PI_CSR_ADDR
  csrr t1, BAR_PO_CSR_ADDR  
  li t2, 0
  beq t0, t1, no_hw_barrier_in_progress
  li t2, 1
  bsg_asm_barsend   // deactivate hw barrier
  
no_hw_barrier_in_progress:
  // save 1 if it has joined the barrier.
  sw t2, 128(s0)


  // By this point, all the context for the current thread should have been saved.
  // Now, start restoring the next thread context.
  la t0, __thread_id
  lw t0, 0(t0)
  addi t0, t0,  1
  li t1, NUM_THREAD
  rem s0, t0, t1  // s0 == next thread id

  // restore DMEM context
  la t0, __bsg_id
  lw t0, 0(t0)
  li t1, NUM_THREAD
  mul t0, t0, t1
  add t0, t0, s0
  li t1, 4096
  mul t0, t0, t1
  la t1, _thread_data_block
  add t0, t0, t1  // t0 = next thread data block addr (DRAM)
  
  li t1, 0
  li t2, 4096
restore_thread_data_context_loop:
  lw t3, 0(t0)
  sw t3, 0(t1)
  addi t0, t0, 4
  addi t1, t1, 4
  bne t1, t2, restore_thread_data_context_loop
  
  // write __thread_id
  la t0, __thread_id
  sw s0, 0(t0)

  // calculate next thread context block addr (DRAM)
  la t0, __bsg_id
  lw t0, 0(t0)
  li t1, NUM_THREAD
  mul t0, t0, t1
  add t0, t0, s0
  li t1, 256
  mul t0, t0, t1
  la t1, _thread_context_block
  add s1, t0, t1  // s1 = next thread context block addr (DRAM)

  // restore mepc
  lw t0, 132(s1)
  csrrw x0, mepc, t0
 
  // restore hw barrier state
  lw t0, 128(s1)
  beq x0, t0, skip_barrier_restore
  bsg_asm_barsend  

skip_barrier_restore:
  // restore registers
  lw x1, 4(s1)
  lw x2, 8(s1)
  lw x3, 12(s1)
  lw x4, 16(s1)
  lw x5, 20(s1)
  lw x6, 24(s1)
  lw x7, 28(s1)
  lw x8, 32(s1)
  lw x10, 40(s1)
  lw x11, 44(s1)
  lw x12, 48(s1)
  lw x13, 52(s1)
  lw x14, 56(s1)
  lw x15, 60(s1)
  lw x16, 64(s1)
  lw x17, 68(s1)
  lw x18, 72(s1)
  lw x19, 76(s1)
  lw x20, 80(s1)
  lw x21, 84(s1)
  lw x22, 88(s1)
  lw x23, 92(s1)
  lw x24, 96(s1)
  lw x25, 100(s1)
  lw x26, 104(s1)
  lw x27, 108(s1)
  lw x28, 112(s1)
  lw x29, 116(s1)
  lw x30, 120(s1)
  lw x31, 124(s1)
  lw x9, 36(s1)

  // exit interrupt
  mret

  





