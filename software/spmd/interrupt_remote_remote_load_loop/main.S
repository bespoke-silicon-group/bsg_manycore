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
  li x1, 0
  li x2, 4096*2-4
  li x3, 0
  li x4, 0
  li x5, 0
  li x6, 0
  li x7, 0
  li x8, 0
  li x9, 0
  li x10,0
  li x11,0
  li x12,0
  li x13,0
  li x14,0
  li x15,0
  li x16,0
  li x17,0
  li x18,0
  li x19,0
  li x20,0
  li x21,0
  li x22,0
  li x23,0
  li x24,0
  li x25,0
  li x26,0
  li x27,0
  li x28,0
  li x29,0
  li x30,0
  li x31,0

  fcvt.s.w f0, x0
  fcvt.s.w f1, x0
  fcvt.s.w f2, x0
  fcvt.s.w f3, x0
  fcvt.s.w f4, x0
  fcvt.s.w f5, x0
  fcvt.s.w f6, x0
  fcvt.s.w f7, x0
  fcvt.s.w f8, x0
  fcvt.s.w f9, x0
  fcvt.s.w f10,x0
  fcvt.s.w f11,x0
  fcvt.s.w f12,x0
  fcvt.s.w f13,x0
  fcvt.s.w f14,x0
  fcvt.s.w f15,x0
  fcvt.s.w f16,x0
  fcvt.s.w f17,x0
  fcvt.s.w f18,x0
  fcvt.s.w f19,x0
  fcvt.s.w f20,x0
  fcvt.s.w f21,x0
  fcvt.s.w f22,x0
  fcvt.s.w f23,x0
  fcvt.s.w f24,x0
  fcvt.s.w f25,x0
  fcvt.s.w f26,x0
  fcvt.s.w f27,x0
  fcvt.s.w f28,x0
  fcvt.s.w f29,x0
  fcvt.s.w f30,x0
  fcvt.s.w f31,x0

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
