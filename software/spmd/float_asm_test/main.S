#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

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

fmv.s.x f0, x0
fmv.s.x f1, x0
fmv.s.x f2, x0
fmv.s.x f3, x0
fmv.s.x f4, x0
fmv.s.x f5, x0
fmv.s.x f6, x0
fmv.s.x f7, x0
fmv.s.x f8, x0
fmv.s.x f9, x0
fmv.s.x f10,x0
fmv.s.x f11,x0
fmv.s.x f12,x0
fmv.s.x f13,x0
fmv.s.x f14,x0
fmv.s.x f15,x0
fmv.s.x f16,x0
fmv.s.x f17,x0
fmv.s.x f18,x0
fmv.s.x f19,x0
fmv.s.x f20,x0
fmv.s.x f21,x0
fmv.s.x f22,x0
fmv.s.x f23,x0
fmv.s.x f24,x0
fmv.s.x f25,x0
fmv.s.x f26,x0
fmv.s.x f27,x0
fmv.s.x f28,x0
fmv.s.x f29,x0
fmv.s.x f30,x0
fmv.s.x f31,x0

_test1:
  li t0, 0x4048f5c3
  fmv.s.x f0, t0
  fsgnj.s f1, f0, f0
  fmv.x.s t1, f1
  bne t1, t1, fail

_test2:
  li t0, 0x40a51eb8
  fmv.s.x f0, t0
  fsgnjn.s f2, f0, f0
  fmv.x.s t1, f1
  li t0, 0xc0a51eb8
  bne t1, t1, fail

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


pass:
  bsg_asm_finish(IO_X_INDEX, 0)

fail:
  bsg_asm_fail(IO_X_INDEX, 0)
