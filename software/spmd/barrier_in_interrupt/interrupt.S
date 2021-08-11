#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// Each tile can save its context info up to N words in DRAM
// Each tiles needs to use its tile id to index into the correct block.
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
_fail_loop:
  j _fail_loop


_remote_interrupt_handler:
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
  sw ra, 28(t0)
  sw s0, 32(t0)
  mv s0, t0   // save your context block addr in s0
  // each tile stores its tile id in myid array.
  la t0, myid
  la t1, __bsg_id
  lw t1, 0(t1)
  slli t2, t1, 2
  add t0, t0, t2
  sw t1, 0(t0)
  // join amoadd barrier
  la a0, amoadd_lock
  la a1, amoadd_alarm
  jal barrier_amoadd
  // restore
  lw t2, 0(s0)
  lw t3, 4(s0)
  lw t4, 8(s0)
  lw t5, 12(s0)
  lw t6, 16(s0)
  lw a0, 20(s0)
  lw a1, 24(s0)
  lw ra, 28(s0)
  lw s0, 32(s0)
  lw t0, 0(x0)
  lw t1, 4(x0)
  // exit interrupt
  mret


// barrier_amoadd
// a0 = amoadd lock add in DRAM
// a1 = amoadd alarm addr in DMEM
barrier_amoadd:
  // set the alarm to zero
  sw x0, 0(a1)
  // send amoadd (+1)
  li t0, 1
  amoadd.w t0, t0, 0(a0)
  // If you are the last to send amoadd, then wake up everyone.
  // Otherwise, fall asleep.
  li t1, (bsg_tiles_X*bsg_tiles_Y)-1
  beq t0, t1, barrier_amoadd_wakeup

barrier_amoadd_sleep:
  lr.w t0, 0(a1)
  li t1, 1
  beq t0, t1, barrier_amoadd_end
  lr.w.aq t0, 0(a1)
  bne t0, t1, barrier_amoadd_sleep
  j barrier_amoadd_end

barrier_amoadd_wakeup:
  // reset amoadd lock to zero.
  sw x0, 0(a0)
  fence
  // wake up every tile
  li t0, 0
  li t2, bsg_tiles_Y

barrier_amoadd_wakeup_loop_y:
  li t1, 0
  li t3, bsg_tiles_X

barrier_amoadd_wakeup_loop_x:
  // calculate the tile-group addr for the amoadd alarm
  li t4, 0x20000000
  slli t5, t0, 24
  add t4, t4, t5
  slli t5, t1, 18
  add t4, t4, t5
  add t4, t4, a1
  li t5, 1
  sw t5, 0(t4)
  addi t1, t1, 1
  bne t1, t3, barrier_amoadd_wakeup_loop_x
  addi t0, t0, 1
  bne t0, t2, barrier_amoadd_wakeup_loop_y

barrier_amoadd_end:
  ret












