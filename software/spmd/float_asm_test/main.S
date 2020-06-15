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
  li t0, 0x4048f5c3
  fmv.s.x f0, t0
  fsgnj.s f1, f0, f0
  fmv.x.s t1, f1
  bne t0, t1, fail

_test2:
  li t0, 0x40a51eb8
  fmv.s.x f0, t0
  fsgnjn.s f2, f0, f0
  fmv.x.s t1, f2
  li t0, 0xc0a51eb8
  bne t0, t1, fail

_test3:
  li t0, 0x42f63efa
  li t1, 0x80000000
  li t2, 0xc2f63efa
  fmv.s.x f2, t0
  fmv.s.x f3, t1
  fsgnjx.s f4, f2, f3
  fmv.x.s t3, f4
  bne t3, t2, fail

_test4:
  li t0, 0x4048f5c3
  li t1, 0x4048f5c3
  add t2, t1, t0
  fmv.s.x f0, t2
  fsgnj.s f7, f0, f0
  fmv.x.s t3, f7
  bne t3, t2, fail
  
_test5:
  li t0, 0x41200000
  li t1, 0x40e00000
  li t2, 0x41880000
  fmv.s.x f0, t0
  fmv.s.x f1, t1
  fmv.s.x f2, t0
  fmv.s.x f3, t1
  fmv.s.x f4, t0
  fmv.s.x f5, t1
  fmv.s.x f6, t0
  fmv.s.x f7, t1
  fmv.s.x f8, t0
  fmv.s.x f9, t1
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  add x0, x0, x0
  fadd.s f10, f0, f1
  fadd.s f11, f2, f3
  fadd.s f12, f4, f5
  fadd.s f13, f6, f7
  fadd.s f14, f8, f9
  fmv.x.s t3, f10
  bne t3, t2, fail
  fmv.x.s t4, f11
  bne t4, t2, fail
  fmv.x.s t5, f12
  bne t5, t2, fail
  fmv.x.s t6, f13
  bne t6, t2, fail
  fmv.x.s t3, f14
  bne t3, t2, fail

_test6:
  li t0, 0x41400000
  li t1, 0xc1400000
  li t2, 0x44d80000
  fmv.s.x f0, t0
  fmv.s.x f1, t1
  fmul.s f2, f0, f1
  fmul.s f2, f2, f1
  fmv.x.s t3, f2
  bne t2, t3, fail

_test7:
  li t0, 0x40a00000
  li t1, 0x40800000
  li t2, 0x40e00000
  li t3, 0x41d80000
  fmv.s.x f0, t0
  fmv.s.x f1, t1
  fmv.s.x f2, t2
  fmul.s f3, f0, f1
  fadd.s f3, f3, f2
  fmv.x.s t4, f3
  bne t4, t3, fail

_test8:
  li t0, 0x41880000
  li t1, 0xc0800000
  fmv.s.x f0, t0
  fmv.s.x f1, t1
  fmin.s f2, f0, f1
  fmax.s f3, f0, f1
  fmv.x.s t2, f2
  fmv.x.s t3, f3
  bne t1, t2, fail
  bne t0, t3, fail

_test9:
  li t0, 0x42c80000
  li t1, 0x43480000
  li t2, 1
  fmv.s.x f0, t0
  fmv.s.x f1, t1
  fadd.s f2, f0, f0
  feq.s t3, f0, f1
  bne t3, x0, fail
  feq.s t3, f1, f2
  bne t3, t2, fail
  flt.s t3, f0, f1
  bne t3, t2, fail
  flt.s t3, f1, f0
  bne t3, x0, fail
  fle.s t3, f1, f2
  bne t3, t2, fail
  fle.s t3, f0, f2
  bne t3, t2, fail
  fle.s t3, f2, f0
  bne t3, x0, fail

_test10:
  li t0, 100
  li t1, 0x42c80000
  fcvt.s.w f11, t0
  fsgnj.s f12, f11, f11
  fmv.x.s t2, f12
  bne t1, t2, fail

_test11:
  li t0, 0xc49a6000
  li t1, -1235
  fmv.s.x f0, t0
  fcvt.w.s t2, f0
  bne t2, t1, fail

_test12:
  li t0, 0x4138e148
  li t1, 12
  fmv.s.x f15, t0
  fcvt.wu.s t2, f15
  bne t2, t1, fail

_test13:
  li t0, 0xff800000
  fmv.s.x f0, t0
  fclass.s t1, f0
  li t2, 1
  bne t2, t1, fail

_test14:
  li t0, 0xfb804800
  fmv.s.x f1, t0
  fclass.s t0, f1
  li t2, 2
  bne t2, t0, fail


_test15:
  li t0, 0x80004800
  li t1, 4
  fmv.s.x f0, t0
  fclass.s t0, f0
  bne t0, t1, fail

_test16:
  li t0, 0x80000000
  li t1, 8
  fmv.s.x f0, t0
  fclass.s t0, f0
  bne t0, t1, fail

_test17:
  li t0, 0x00000000
  li t1, 16
  fmv.s.x f0, t0
  fclass.s t0, f0
  bne t0, t1, fail

_test18:
  li t0, 0x00084400
  li t1, 32
  fmv.s.x f0, t0
  fclass.s t0, f0
  bne t0, t1, fail

_test19:
  li t0, 0x63084400
  li t1, 64
  fmv.s.x f0, t0
  fclass.s t0, f0
  bne t0, t1, fail

_test20:
  li t0, 0x7f800000
  li t1, 128
  fmv.s.x f0, t0
  fclass.s t0, f0
  bne t0, t1, fail

_test21:
  li t0, 0x7f800003
  li t1, 256
  fmv.s.x f0, t0
  fclass.s t0, f0
  bne t0, t1, fail

_test22:
  li t0, 0x7fc00003
  li t1, 512
  fmv.s.x f0, t0
  fclass.s t0, f0
  bne t0, t1, fail

_test23:
  la t0, float_dmem_arr
  li t1, 0x41200000
  sw t1, 0(t0)
  li t1, 0x41a00000
  sw t1, 4(t0)
  flw f0, 0(t0)
  flw f1, 4(t0)
  fadd.s f2, f0, f1
  fadd.s f3, f1, f0
  fadd.s f4, f0, f1
  li t2, 0x41f00000
  fmv.x.s t3, f2
  bne t2, t3, fail
  fmv.x.s t4, f3
  bne t2, t4, fail
  fmv.x.s t5, f4
  bne t2, t5, fail

_test24:
  la t0, float_dmem_arr
  li t1, 0x4048f5c3
  fmv.s.x f0, t1 
  fsw f0, 8(t0)
  addi t0, t0, 4
  lw t2, 4(t0)
  bne t1, t2, fail

_test25:
  add t0, x0, x0
  add t1, x0, x0
  add t2, x0, x0
  la t0, float_dmem_arr
  li t1, 0x4048f5c3
  fmv.s.x f0, t1 
  fsw f0, 8(t0)
  lw t2, 8(t0)
  bne t1, t2, fail

_test26:
  la t0, float_dram_arr
  li t1, 0x41400000
  li t2, 0x41500000
  sw t1, 0(t0)
  sw t2, 4(t0)
  flw f0, 0(t0)
  flw f1, 4(t0)
  fmul.s f2, f0, f1
  fmv.x.s t3, f2
  li t4, 0x431c0000
  bne t3, t4, fail

_test27:
  la t0, float_dram_arr
  li t1, 2
  li t2, 16
  li t3, 0x3f800000
  sw t3, 0(t0)
  sw t3, 4(t0)

_test27_loop:
  slli t3, t1, 2
  add t3, t3, t0
  flw f0, -8(t3)
  flw f1, -4(t3)
  fadd.s f2, f0, f1
  fsw f2, 0(t3)
  addi t1, t1, 1
  bne t1, t2, _test27_loop  

_test27_end:
  addi t3, t2, -1
  slli t3, t3, 2
  add t3, t3, t0
  lw t5, 0(t3)
  li t4, 0x4476c000
  bne t4, t5, fail


pass:
  bsg_asm_finish(IO_X_INDEX, 0)

pass_loop:
  beq x0, x0, pass_loop

fail:
  bsg_asm_fail(IO_X_INDEX, 0)

fail_loop:
  beq x0, x0, fail_loop
