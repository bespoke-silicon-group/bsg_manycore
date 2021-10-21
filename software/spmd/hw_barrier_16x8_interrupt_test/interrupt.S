// remote interrupt handler saves the context info including whether the barrier has entered or not.

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// Each tile can save its context info up to N words in DRAM
// Each tile needs to use its tile id to index into the correct block.
#define CONTEXT_BLOCK_SIZE 32
.section .dram, "aw"
.globl context_block_arr
context_block_arr: .space (CONTEXT_BLOCK_SIZE*bsg_tiles_X*bsg_tiles_Y*4), 0x0

// amoadd barrier variables
.globl amoadd_lock
.globl amoadd_alarm
// tile id
.globl __bsg_id
.globl myid

// interrupt text section
.section .text.interrupt, "a"
_remote_interrupt:
  j _remote_interrupt_handler


_trace_interrupt:
  bsg_asm_fail(IO_X_INDEX, 0);
fail_loop:
  j fail_loop



_remote_interrupt_handler:
  // wait for outstanding remote loads to finish.
  fence
  // save two registers (t0, t1) to the reserved spot in DMEM
  sw t0, 0(x0)
  sw t1, 4(x0)
  // turn off remote pending bit
  li t0, 0x10000
  csrrc x0, mip, t0
  // calculate its tile context block addr
  la t0, context_block_arr
  la t1, __bsg_id
  lw t1, 0(t1)
  slli t1, t1, 7
  add t0, t0, t1 // t0 = your context block addr
  // save some context info
  sw t2, 0(t0)
  sw t3, 4(t0)
  sw t4, 8(t0)
  sw t5, 12(t0)
  sw t6, 16(t0)
  sw a0, 20(t0)
  sw a1, 24(t0)
  sw a2, 28(t0)
  sw ra, 32(t0)
  sw s0, 36(t0)
  mv s0, t0   // save your context block addr in s0

  // join amoadd barrier
  la a0, amoadd_lock
  la a1, amoadd_alarm
  jal bsg_barrier_amoadd

  // check if the tile has join a barrier or not
  csrr t0, BAR_PI_CSR_ADDR
  csrr t1, BAR_PO_CSR_ADDR
  li t2, 0
  beq t0, t1, no_barrier_in_progress
  li t2, 1
  bsg_asm_barsend  

no_barrier_in_progress:
  // save 1 if it has join the barrier.
  sw t2, 40(s0)

  // increment an array for testing purpose
  la t0, myid
  la t1, __bsg_id
  lw t1, 0(t1)
  slli t1, t1, 2
  add t0, t0, t1
  li t2, 1
  amoadd.w.aq x0, t2, 0(t0)

  // restore barrier state
  lw t0, 40(s0)
  beq t0, x0, skip_barrier_restore
  bsg_asm_barsend


skip_barrier_restore:
  // restore
  lw t2, 0(s0)
  lw t3, 4(s0)
  lw t4, 8(s0)
  lw t5, 12(s0)
  lw t6, 16(s0)
  lw a0, 20(s0)
  lw a1, 24(s0)
  lw a2, 28(s0)
  lw ra, 32(s0)
  lw s0, 36(s0)
  lw t0, 0(x0)
  lw t1, 4(x0)

  // exit interrupt
  mret
