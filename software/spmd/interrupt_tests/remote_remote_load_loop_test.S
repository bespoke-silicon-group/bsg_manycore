// Author: Tommy
// testing trace interrupt while remote load looping

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"


.data
 _dmem_arr: .space 64

.section .dram, "aw"
  dram_arr: .space 1024

.text
.globl _start
_remote_interrupt:
  // clear mip.remote
  li x1, 0x10000
  csrrc x0, mip, x1
  mret
_trace_interrupt:
  j fail

_start:
  bsg_asm_init_regfile

  // enable mstatus.MIE
  li x1, 0x8
  csrrw x0, mstatus, x1

  // enable mie.remote
  li x1, 0x10000
  csrrw x0, mie, x1

  // count down from 20
  li x2, 20
  la x3, dram_arr
  li x4, bsg_tile_group_remote_interrupt_ptr(0,0)
  li x5, 1
// load 16 words at a time
.org 4096
countdown_loop:
  beq x0, x2, pass
  lw x10, 0(x3)
  lw x11, 4(x3)
  lw x12, 8(x3)
  lw x13, 12(x3)
  lw x14, 16(x3)
  lw x15, 20(x3)
  lw x16, 24(x3)
  lw x17, 28(x3)
  lw x18, 32(x3)
  lw x19, 36(x3)
  lw x20, 40(x3)
  lw x21, 44(x3)
  lw x22, 48(x3)
  lw x23, 52(x3)
  lw x24, 56(x3)
  lw x25, 60(x3)
  sw x5, 0(x4)
  addi x3, x3, 64
  addi x2, x2, -1
  j countdown_loop

// don't go here
  j fail



// returning from interrupt
pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
