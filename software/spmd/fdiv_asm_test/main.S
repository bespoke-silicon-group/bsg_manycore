#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.data
  float_dmem_arr: .space 64
.section .dram, "aw"
  float_dram_arr: .space 64

.text
li x0, 0
li x1, 0
li x2, 0
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
  li x1, 0x43960000 //300
  li x2, 0x41700000 //15
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fdiv.s f2, f0, f1
  fmv.x.s x31, f2
  li x3, 0x41a00000
  bne x3, x31, fail
  
_test2:
  li x2, 0x43960000 //300
  li x1, 0x41700000 //15
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fdiv.s f2, f0, f1
  fmv.x.s x31, f2
  li x3, 0x3d4ccccd
  bne x3, x31, fail

_test3:
  li x1, 0x43960000 //300
  li x2, 0x41700000 //15
  li x3, 0x43c80000 //400
  li x4, 0x41c80000 //25
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fmv.s.x f2, x3
  fmv.s.x f3, x4
  fdiv.s f4, f0, f1
  fdiv.s f5, f2, f3
  fmv.x.s x30, f4
  fmv.x.s x31, f5
  li x5, 0x41a00000
  li x6, 0x41800000
  bne x5, x30, fail
  bne x6, x31, fail


_test4:
  li x1, 0x43100000
  li x2, 0x41400000
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fdiv.s f2, f0, f1
  fdiv.s f3, f2, f1
  fmv.x.s x31, f3
  li x3, 0x3f800000
  bne x3, x31, fail


_test5:
  li x1, 0x42c80000 // 100
  li x2, 0x41200000 // 10
  la x3, float_dmem_arr
  sw x1, 0(x3)
  sw x2, 4(x3)
  flw f0, 0(x3)
  flw f1, 4(x3)
  fdiv.s f2, f0, f1
  flw f3, 4(x3)
  fdiv.s f4, f2, f3
  fmv.x.s x31, f4
  li x30, 0x3f800000
  bne x30, x31, fail

_test6:
  li x1, 0x42c80000 // 100
  li x2, 0x41200000 // 10
  la x3, float_dmem_arr
  sw x1, 0(x3)
  sw x2, 4(x3)
  flw f0, 0(x3)
  flw f1, 4(x3)
  fdiv.s f2, f0, f1
  flw f3, 4(x3)
  fdiv.s f4, f2, f3
  fsw f4, 8(x3)
  lw x31, 8(x3)
  li x30, 0x3f800000
  bne x30, x31, fail

_test7:
  li x1, 0xc2f20000 // -121
  li x2, 0x41300000 // 11
  la x3, float_dmem_arr
  la x4, float_dram_arr
  sw x1, 0(x3)
  sw x2, 0(x4)
  flw f0, 0(x4) //f0= 11
  flw f1, 0(x3) // f1 = -121
  fdiv.s f2, f1, f0 // f2 = -11
  fmv.x.s x31, f2
  li x30, 0xc1300000
  bne x30, x31, fail

_test8:
  fscsr x0, x0
  li x1, 0x449a4000 // 1234
  la x2, float_dram_arr
  sw x1, 0(x2)
  flw f0, 0(x2)
  fmv.s.x f1, x0
  fdiv.s f2, f0, f1
  fmv.x.s x31, f2
  li x30, 0x7f800000 // +Inf
  bne x31, x30, fail
  frflags x8
  li x9, 0x8
  bne x8, x9, fail

_test9:
  li x1, 0x3f800000 // 1
  li x2, 0x41c00000 // 24
  li x3, 0x40400000 // 3
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fmv.s.x f2, x3
  fdiv.s f3, f1, f2
  fadd.s f0, f0, f0 // 2
  fadd.s f0, f0, f0 // 4
  fadd.s f0, f0, f0 // 8
  fadd.s f0, f0, f0 // 16
  fadd.s f0, f0, f0 // 32
  fadd.s f0, f0, f0 // 64
  fmv.x.s x30, f3
  fmv.x.s x31, f0
  li x4, 0x41000000
  li x5, 0x42800000
  bne x30, x4, fail
  bne x31, x5, fail
  

_test10:
  li x1, 0x3f800000 // 1
  li x2, 0x41c00000 // 24
  li x3, 0x40400000 // 3
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fmv.s.x f2, x3
  fdiv.s f3, f1, f2
  fadd.s f0, f0, f0 // 2
  fadd.s f0, f0, f0 // 4
  fadd.s f0, f0, f0 // 8
  fadd.s f0, f0, f0 // 16
  fadd.s f0, f0, f0 // 32
  fadd.s f0, f0, f0 // 64
  fadd.s f0, f0, f0 // 128
  fadd.s f0, f0, f0 // 256
  fadd.s f0, f0, f0 // 512
  fadd.s f0, f0, f0 // 1024
  fmv.x.s x30, f3
  fmv.x.s x31, f0
  li x4, 0x41000000
  li x5, 0x44800000
  bne x30, x4, fail
  bne x31, x5, fail
  
  

pass:
  bsg_asm_finish(IO_X_INDEX,0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
