#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.data
  float_dmem_arr: .space 64 // array of 16 floats

.section .dram, "aw"
  float_dram_arr: .space 64

.text
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




_test1:
  li x1, 0x43100000 // 144
  fmv.s.x f0, x1
  fsqrt.s f1, f0
  fmv.x.s x31, f1
  li x30, 0x41400000 // 12
  bne x30, x31, fail


_test2:
  li x1, 0x42c80000 // 100
  la x2, float_dmem_arr
  sw x1, 0(x2)
  flw f1, 0(x2)
  fsqrt.s f2, f1
  fmv.x.s x31, f2 
  li x30, 0x41200000
  bne x30, x31, fail


_test3:
  li x1, 0x42c80000 // 100
  la x2, float_dram_arr
  sw x1, 0(x2)
  flw f1, 0(x2)
  fsqrt.s f2, f1
  fmv.x.s x31, f2 
  li x30, 0x41200000
  bne x30, x31, fail


_test4:
  li x1, 0x42f20000 // 121
  li x2, 0x43290000 // 169
  la x3, float_dram_arr
  sw x1, 0(x3)  
  sw x2, 4(x3)  
  flw f3, 0(x3)
  flw f4, 4(x3)
  fsqrt.s f5, f3
  fsqrt.s f5, f4
  fmv.x.s x31, f5
  li x30, 0x41500000
  bne x30, x31, fail 

_test5:
  li x1, 0x41100000 // 9
  li x2, 0x41800000 // 16
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fadd.s f2, f1, f0
  fsqrt.s f2, f2
  fmv.x.s x31, f2
  li x30, 0x40a00000
  bne x30, x31, fail

_test6:
  li x1, 0x41100000 // 9
  li x2, 0x41800000 // 16
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fsqrt.s f1, f1
  fadd.s f1, f1, f0
  fmv.x.s x31, f1
  li x30, 0x41500000
  bne x30, x31, fail


pass:
  bsg_asm_finish(IO_X_INDEX, 0)

pass_loop:
  beq x0, x0, pass_loop

fail:
  bsg_asm_fail(IO_X_INDEX, 0)

fail_loop:
  beq x0, x0, fail_loop

