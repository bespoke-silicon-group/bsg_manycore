//  barrier_context_switch test
//
//  Each tile runs two threads. Each thread runs barrier 10 times.
//  There is a counter that keeps track of the progress.
//  After a thread joins a barrier, it puts itself into a remote interrupt, and then waits for the barrier to complete.
//  The remote interrupt handler saves the current thread's context (e.g. the counter, barrier cfg)
//  and switches to the other thread.

// Register allocation
// s0     = progress counter
// s1     = self-remote interrupt addr, shared by both threads



#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl bsg_set_tile_x_y
.globl __bsg_id
.globl __bsg_x
.globl __bsg_y

.section .dram, "aw"
  barrier_cfg_4x4: .space(4*4*4)

.text
_remote_interrupt:
  j _remote_interrupt_handler

// trace interrupt not enabled.
_trace_interrupt:
  j fail

_remote_interrupt_handler:
  // clear mip.remote
  li t0, 0x10000
  csrrc x0, mip, t0

  // In general, we don't allow joining a new barrier without completing the one already in progress.
  // Before we switch thread, we finish the current barrier in progress, if any.
  // This way, we can be sure that the new thread can safely join its own barrier.
  barwait
  // gather the current thread context in temp registers.
  csrrs t0, mepc, x0
  csrrs t1, barcfg, x0
  mv t2, s0
  // restore the other thread
  lw  t3, 0(sp)   // mepc
  lw  t4, 4(sp)   // barrier cfg
  lw  s0, 8(sp)   // progress counter, s1
  addi sp, sp, 12
  csrrw x0, mepc, t3
  csrrw x0, barcfg, t4
  // store the current thread contex in the stack
  addi sp, sp, -12
  lw t0, 0(sp)
  lw t1, 4(sp)
  lw t2, 8(sp)
  // launch the other thread
  mret

// start pc from here. 
_start:
  bsg_asm_init_regfile

  // enable interrupt
  li t0, 0x8
  csrrw x0, mstatus, t0

  // enable remote interrupt
  li t0, 0x10000 
  csrrw x0, mie, t0
  
  // everyone calculates __bsg_id, etc.
  // they are calculated and live in dmem.
  // both threads share the variables intialized by this routine.
  call bsg_set_tile_x_y

  // calculate remote interrupt EVA of itself, and store it in s1
  // tommy: Add remote-self EVA space? then most of this computation can go away.
  li s1, 0x20000000
  la t0, __bsg_y
  la t1, __bsg_x
  lw t0, 0(t0)    // __bsg_y
  lw t1, 0(t1)    // __bsg_x
  slli t0, t0, 24 //  __bsg_y << 24
  slli t1, t1, 18 //  __bsg_x << 18
  li   t2, 0xfffc   // mip_remote EPA
  add s1, s1, t0
  add s1, s1, t1
  add s1, s1, t2
  // setup thread 2
  la t0, barrier_start:
  li t1, 10   // progress counter
  // push these down on the stack
  // the stack should look like:
  // 0(sp)    = mepc
  // 4(sp)    = barrier cfg
  // 8(sp)    = progress counter, s1
  addi sp, sp, -12
  sw t0, 0(sp)
  sw x0, 4(sp)
  sw t1, 8(sp)

barrier_start:
  // barcfg CSR format
  //    barcfg represents a barrier state needed for storing and restoring itself, across context switch.
  // bit[15:0]  = input mask
  // bit[23:16] = output dir
  // bit[24]    = Pi (barrier switch register) (sense bit)
  //              the thread's barrier sense context is stored here.
  // bit[31:25] = unused

  // everyone grabs its barrier cfg by indexing with __bsg_id.
  la t0, barrier_cfg_4x4
  la t1, __bsg_id
  slli t1, t1, 2
  add t0, t0, t1          // calculated barrier_cfg_4x4[__bsg_id]
  lw t0, 0(t0)            // load the barrier cfg
  csrrw x0, barr, t0      // configure the barrier csr
  // set the progress counter to 10
  li s0, 10              

barrier_loop:
  // join barrier
  barjoin
  // send yourself a remote interrupt
  li t0, 1
  sw t0, 0(s1)  // send remote interrupt
  // sometimes during these nops, the remote interrupt will arrive
  nop
  nop
  nop
  nop
  // wait for barrier 
  barwait
  // decrement progress counter
  addi s0, s0, -1
  bne s0, x0, barrier_loop


// FINISH
pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
