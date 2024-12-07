#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// initialize
.text
_start:
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

// INT regfile
li x1, 0xffffffff
xor x1, x1, x1
bne x1, x0, fail
li x2, 0xffffffff
xor x2, x2, x2
bne x2, x0, fail
li x3, 0xffffffff
xor x3, x3, x3
bne x3, x0, fail
li x4, 0xffffffff
xor x4, x4, x4
bne x4, x0, fail
li x5, 0xffffffff
xor x5, x5, x5
bne x5, x0, fail
li x6, 0xffffffff
xor x6, x6, x6
bne x6, x0, fail
li x7, 0xffffffff
xor x7, x7, x7
bne x7, x0, fail
li x8, 0xffffffff
xor x8, x8, x8
bne x8, x0, fail
li x9, 0xffffffff
xor x9, x9, x9
bne x9, x0, fail
li x10, 0xffffffff
xor x10, x10, x10
bne x10, x0, fail
li x11, 0xffffffff
xor x11, x11, x11
bne x11, x0, fail
li x12, 0xffffffff
xor x12, x12, x12
bne x12, x0, fail
li x13, 0xffffffff
xor x13, x13, x13
bne x13, x0, fail
li x14, 0xffffffff
xor x14, x14, x14
bne x14, x0, fail
li x15, 0xffffffff
xor x15, x15, x15
bne x15, x0, fail
li x16, 0xffffffff
xor x16, x16, x16
bne x16, x0, fail
li x17, 0xffffffff
xor x17, x17, x17
bne x17, x0, fail
li x18, 0xffffffff
xor x18, x18, x18
bne x18, x0, fail
li x19, 0xffffffff
xor x19, x19, x19
bne x19, x0, fail
li x20, 0xffffffff
xor x20, x20, x20
bne x20, x0, fail
li x21, 0xffffffff
xor x21, x21, x21
bne x21, x0, fail
li x22, 0xffffffff
xor x22, x22, x22
bne x22, x0, fail
li x23, 0xffffffff
xor x23, x23, x23
bne x23, x0, fail
li x24, 0xffffffff
xor x24, x24, x24
bne x24, x0, fail
li x25, 0xffffffff
xor x25, x25, x25
bne x25, x0, fail
li x26, 0xffffffff
xor x26, x26, x26
bne x26, x0, fail
li x27, 0xffffffff
xor x27, x27, x27
bne x27, x0, fail
li x28, 0xffffffff
xor x28, x28, x28
bne x28, x0, fail
li x29, 0xffffffff
xor x29, x29, x29
bne x29, x0, fail
li x30, 0xffffffff
xor x30, x30, x30
bne x30, x0, fail
li x31, 0xffffffff
xor x31, x31, x31
bne x31, x0, fail


// FP regfile
li t0, 98010000 // = 9900*9900
li t2, 9900

fcvt.s.w f0, t0
fsqrt.s f0, f0
fcvt.w.s t1, f0
bne t1, t2, fail

fcvt.s.w f1, t0
fsqrt.s f1, f1
fcvt.w.s t1, f1
bne t1, t2, fail

fcvt.s.w f2, t0
fsqrt.s f2, f2
fcvt.w.s t1, f2
bne t1, t2, fail

fcvt.s.w f3, t0
fsqrt.s f3, f3
fcvt.w.s t1, f3
bne t1, t2, fail

fcvt.s.w f4, t0
fsqrt.s f4, f4
fcvt.w.s t1, f4
bne t1, t2, fail

fcvt.s.w f5, t0
fsqrt.s f5, f5
fcvt.w.s t1, f5
bne t1, t2, fail

fcvt.s.w f6, t0
fsqrt.s f6, f6
fcvt.w.s t1, f6
bne t1, t2, fail

fcvt.s.w f7, t0
fsqrt.s f7, f7
fcvt.w.s t1, f7
bne t1, t2, fail

fcvt.s.w f8, t0
fsqrt.s f8, f8
fcvt.w.s t1, f8
bne t1, t2, fail

fcvt.s.w f9, t0
fsqrt.s f9, f9
fcvt.w.s t1, f9
bne t1, t2, fail

fcvt.s.w f10, t0
fsqrt.s f10, f10
fcvt.w.s t1, f10
bne t1, t2, fail

fcvt.s.w f11, t0
fsqrt.s f11, f11
fcvt.w.s t1, f11
bne t1, t2, fail

fcvt.s.w f12, t0
fsqrt.s f12, f12
fcvt.w.s t1, f12
bne t1, t2, fail

fcvt.s.w f13, t0
fsqrt.s f13, f13
fcvt.w.s t1, f13
bne t1, t2, fail

fcvt.s.w f14, t0
fsqrt.s f14, f14
fcvt.w.s t1, f14
bne t1, t2, fail

fcvt.s.w f15, t0
fsqrt.s f15, f15
fcvt.w.s t1, f15
bne t1, t2, fail

fcvt.s.w f16, t0
fsqrt.s f16, f16
fcvt.w.s t1, f16
bne t1, t2, fail

fcvt.s.w f17, t0
fsqrt.s f17, f17
fcvt.w.s t1, f17
bne t1, t2, fail

fcvt.s.w f18, t0
fsqrt.s f18, f18
fcvt.w.s t1, f18
bne t1, t2, fail

fcvt.s.w f19, t0
fsqrt.s f19, f19
fcvt.w.s t1, f19
bne t1, t2, fail

fcvt.s.w f20, t0
fsqrt.s f20, f20
fcvt.w.s t1, f20
bne t1, t2, fail

fcvt.s.w f21, t0
fsqrt.s f21, f21
fcvt.w.s t1, f21
bne t1, t2, fail

fcvt.s.w f22, t0
fsqrt.s f22, f22
fcvt.w.s t1, f22
bne t1, t2, fail

fcvt.s.w f23, t0
fsqrt.s f23, f23
fcvt.w.s t1, f23
bne t1, t2, fail

fcvt.s.w f24, t0
fsqrt.s f24, f24
fcvt.w.s t1, f24
bne t1, t2, fail

fcvt.s.w f25, t0
fsqrt.s f25, f25
fcvt.w.s t1, f25
bne t1, t2, fail

fcvt.s.w f26, t0
fsqrt.s f26, f26
fcvt.w.s t1, f26
bne t1, t2, fail

fcvt.s.w f27, t0
fsqrt.s f27, f27
fcvt.w.s t1, f27
bne t1, t2, fail

fcvt.s.w f28, t0
fsqrt.s f28, f28
fcvt.w.s t1, f28
bne t1, t2, fail

fcvt.s.w f29, t0
fsqrt.s f29, f29
fcvt.w.s t1, f29
bne t1, t2, fail

fcvt.s.w f30, t0
fsqrt.s f30, f30
fcvt.w.s t1, f30
bne t1, t2, fail

fcvt.s.w f31, t0
fsqrt.s f31, f31
fcvt.w.s t1, f31
bne t1, t2, fail


pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  j fail_loop
