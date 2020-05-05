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
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  li x3, 0x40a00000 // 5.0
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fmv.s.x f2, x3
  fmadd.s f4, f0, f1, f2
  fmv.x.s x5, f4
  li x4, 0x41300000 // 11.0
  bne x5, x4, fail

_test2:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  li x3, 0x40a00000 // 5.0
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fmv.s.x f2, x3
  fmsub.s f4, f0, f1, f2
  fmv.x.s x5, f4
  li x4, 0x3f800000 // 1.0
  bne x5, x4, fail


_test3:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  li x3, 0x40a00000 // 5.0
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fmv.s.x f2, x3
  fnmsub.s f4, f0, f1, f2
  fmv.x.s x5, f4
  li x4, 0xbf800000 // -1.0
  bne x5, x4, fail

_test4:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  li x3, 0x40a00000 // 5.0
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fmv.s.x f2, x3
  fnmadd.s f4, f0, f1, f2
  fmv.x.s x5, f4
  li x4, 0xc1300000 // -11.0
  bne x5, x4, fail

_test5:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  li x3, 0x40a00000 // 5.0
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fmv.s.x f2, x3
  fmadd.s f3, f0, f1, f2 // f3 = 11.0
  fmadd.s f4, f1, f2, f3 // f4 = 26.0
  fmadd.s f5, f2, f3, f4 // f5 = 81.0
  fmadd.s f6, f3, f4, f5 // f6 = 376.0
  fmv.x.s x31, f6
  li x4, 0x43b78000
  bne x31, x4, fail

_test6:
  li x1, 0x40000000 // 2.0
  fmv.s.x f0, x1
  fmadd.s f1, f0, f0, f0 // f1 = 6.0
  fmv.x.s x31, f1
  li x4, 0x40c00000
  bne x31, x4, fail
  
_test7:
  li x1, 0x40000000 // 2.0
  fmv.s.x f0, x1
  fmadd.s f1, f0, f0, f0 // f1 = 6.0
  fmadd.s f2, f1, f1, f1 // f2 = 42.0
  fmv.x.s x31, f2
  li x4, 0x42280000
  bne x31, x4, fail

_test8:
  li x1, 0x40000000 // 2.0
  fmv.s.x f0, x1
  fmadd.s f1, f0, f0, f0 // f1 = 6.0
  fmadd.s f2, f1, f1, f1 // f2 = 42.0
  fmv.x.s x31, f2
  li x4, 0x42280000
  bne x31, x4, fail

_test9:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  fmv.s.x f0, x1
  fmv.s.x f1, x2
  fmadd.s f0, f0, f0, f1 // f0 = 7
  fmadd.s f1, f1, f1, f0 // f0 = 16
  fmv.x.s x30, f0
  fmv.x.s x31, f1
  li x4, 0x40e00000
  li x5, 0x41800000
  bne x4, x30, fail
  bne x5, x31, fail
  
_test10:
  li x1, 0x40000000 // 2
  fmv.s.x f0, x1
  fmadd.s f1, f0, f0, f0  // f1 = 6
  fmadd.s f1, f1, f1, f1  // f1= 42
  fmv.x.s x31, f1
  li x4, 0x42280000
  bne x4, x31, fail 

_test11:
  li x1, 0x40000000 // 2
  fmv.s.x f0, x1
  fmadd.s f1, f0, f0, f0  // f1 = 6
  fmadd.s f1, f1, f1, f1  // f1= 42
  fmadd.s f1, f0, f0, f1  // f1= 46
  fmv.x.s x31, f1
  li x4, 0x42380000
  bne x4, x31, fail 

_test12:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  li x3, 0x40a00000 // 5.0
  la x4, float_dmem_arr
  sw x1, 0(x4)
  sw x2, 4(x4)
  sw x3, 8(x4)
  flw f0, 0(x4)
  flw f1, 4(x4)
  flw f2, 8(x4)
  fmadd.s f3, f0, f1, f2
  fmv.x.s x31, f3
  li x5, 0x41300000
  bne x5, x31, fail


_test13:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  li x3, 0x40a00000 // 5.0
  la x4, float_dram_arr
  sw x1, 0(x4)
  sw x2, 4(x4)
  sw x3, 8(x4)
  flw f0, 0(x4)
  flw f1, 4(x4)
  flw f2, 8(x4)
  fmadd.s f3, f0, f1, f2
  fmv.x.s x31, f3
  li x5, 0x41300000
  bne x5, x31, fail


_test14:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  li x3, 0x40a00000 // 5.0
  la x4, float_dmem_arr
  sw x1, 0(x4)
  sw x2, 4(x4)
  flw f0, 0(x4)
  flw f1, 4(x4)
  fmv.s.x f2, x3
  fmadd.s f3, f0, f1, f2
  fmv.x.s x31, f3
  li x5, 0x41300000
  bne x5, x31, fail

_test15:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  li x3, 0x40a00000 // 5.0
  la x4, float_dram_arr
  sw x1, 0(x4)
  sw x2, 4(x4)
  flw f0, 0(x4)
  flw f1, 4(x4)
  fmv.s.x f2, x3
  fmadd.s f3, f0, f1, f2
  fmv.x.s x31, f3
  li x5, 0x41300000
  bne x5, x31, fail


_test16:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  la x4, float_dmem_arr
  sw x1, 0(x4)
  sw x2, 4(x4)
  flw f0, 0(x4)
  flw f1, 4(x4)
  fmadd.s f2, f0, f0, f1 // f2 = 7
  fmadd.s f3, f0, f1, f2 // f3 = 13
  fmv.x.s x31, f3
  li x5, 0x41500000
  bne x5, x31, fail

_test17:
  li x1, 0x40000000 // 2.0
  li x2, 0x40400000 // 3.0
  la x4, float_dram_arr
  sw x1, 0(x4)
  sw x2, 4(x4)
  flw f0, 0(x4)
  flw f1, 4(x4)
  fmadd.s f2, f0, f0, f1 // f2 = 7
  fmadd.s f3, f0, f1, f2 // f3 = 13
  fmv.x.s x31, f3
  li x5, 0x41500000
  bne x5, x31, fail

_test18:
  li x1, 0x40a00000 // 5.0
  li x2, 0x40e00000 // 7.0
  li x3, 0x40800000 // 4.0
  la x4, float_dmem_arr
  la x5, float_dram_arr
  sw x1, 0(x4)
  sw x3, 4(x4)
  sw x2, 0(x5)
  flw f0, 0(x4) // 5
  flw f1, 0(x5) // 7
  flw f2, 4(x4) // 4
  fmadd.s f3, f0, f1, f2 // f3 = 39
  fmv.x.s x31, f3
  li x5, 0x421c0000
  bne x5, x31, fail


_test19:
  li x1, 0x41400000 // 12
  li x2, 0x41500000 // 13
  la x3, float_dmem_arr 
  la x4, float_dram_arr 
  sw x1, 0(x3)
  sw x2, 0(x4)
  flw f0, 0(x4)
  flw f1, 0(x4)
  flw f2, 0(x4)
  flw f0, 0(x3)
  flw f1, 0(x3)
  flw f2, 0(x3)
  fmadd.s f3, f0, f1, f2
  fmv.x.s x31, f3
  li x5, 0x431c0000
  bne x5, x31, fail 

_test20:
  li x1, 0x41400000 // 12
  li x2, 0x41500000 // 13
  la x3, float_dmem_arr 
  la x4, float_dram_arr 
  sw x1, 0(x3)
  sw x2, 0(x4)
  flw f0, 0(x4)
  flw f1, 0(x4)
  flw f2, 0(x4)
  flw f0, 0(x3)
  flw f1, 0(x3)
  flw f2, 0(x3)
  fmadd.s f3, f0, f1, f2
  fsw f3, 4(x4)
  lw x31, 4(x4)
  li x5, 0x431c0000
  bne x5, x31, fail 

_test21:
  li x1, 0x41400000 // 12
  li x2, 0x41500000 // 13
  la x3, float_dmem_arr 
  la x4, float_dram_arr 
  sw x1, 0(x3)
  sw x2, 0(x4)
  flw f0, 0(x4)
  flw f0, 0(x3)
  flw f1, 0(x4)
  flw f1, 0(x3)
  flw f2, 0(x4)
  flw f2, 0(x3)
  fmadd.s f3, f0, f1, f2
  fmv.x.s x31, f3
  li x5, 0x431c0000
  bne x5, x31, fail 

_test22:
  li x1, 0x41400000 // 12
  li x2, 0x41500000 // 13
  la x3, float_dmem_arr 
  la x4, float_dram_arr 
  sw x1, 0(x3)
  sw x2, 0(x4)
  flw f0, 0(x4)
  flw f0, 0(x3)
  flw f1, 0(x4)
  flw f1, 0(x3)
  flw f2, 0(x4)
  flw f2, 0(x3)
  fmadd.s f3, f0, f1, f2
  flw f3, 0(x4)
  fmv.x.s x31, f3
  li x5, 0x41500000
  bne x5, x31, fail 


pass:
  bsg_asm_finish(IO_X_INDEX,0)
pass_loop:
  beq x0, x0, pass_loop 
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop 
