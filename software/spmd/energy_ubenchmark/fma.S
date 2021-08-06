#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile
  li t0, 0x3f800000 
  fmv.s.x f0, t0
  li t0, 0x3de56042
  fmv.s.x f1, t0
  li t0, 0xc61c4c00
  fmv.s.x f2, t0
  li t0, 0xb9adbfc1
  fmv.s.x f3, t0
  li t0, 0x4ab6997e
  fmv.s.x f4, t0
  li t0, 0x41700000
  fmv.s.x f5, t0
  li t0, 0xc2c80000
  fmv.s.x f6, t0
  li t0, 0xc61d8c00
  fmv.s.x f7, t0
  li t0, 0xc9762b70
  fmv.s.x f8, t0
  li t0, 0x49109bb2
  fmv.s.x f9, t0
  li t0, 0xba9496fb
  fmv.s.x f10, t0
  li t0, 0x40490fd8
  fmv.s.x f11, t0
  li t0, 0xc29ade4f
  fmv.s.x f12, t0
  li t0, 0xc29ade4f
  fmv.s.x f13, t0
  li t0, 0xc138cce4
  fmv.s.x f14, t0
  li t0, 0x55116c0f
  fmv.s.x f15, t0
  nop
  nop
  nop

  bsg_asm_saif_start
  # fmadd x 25 
  fmadd.s f16, f1,  f2,  f3
  fmadd.s f17, f2,  f3,  f4
  fmadd.s f18, f3,  f4,  f5
  fmadd.s f19, f4,  f5,  f6
  fmadd.s f20, f5,  f6,  f7

  fmadd.s f21, f6,  f7,  f8
  fmadd.s f22, f7,  f8,  f9
  fmadd.s f23, f8,  f9,  f10
  fmadd.s f24, f9,  f10, f11
  fmadd.s f25, f10, f11, f12

  fmadd.s f26, f11, f12, f13
  fmadd.s f27, f12, f13, f14
  fmadd.s f28, f13, f14, f15
  fmadd.s f29, f14, f15, f0
  fmadd.s f30, f15, f0,  f1

  fmadd.s f31, f0,  f1,  f2
  fmadd.s f16, f1,  f2,  f3
  fmadd.s f17, f2,  f3,  f4
  fmadd.s f18, f3,  f4,  f5
  fmadd.s f19, f4,  f5,  f6

  fmadd.s f20, f5,  f6,  f7
  fmadd.s f21, f6,  f7,  f8
  fmadd.s f22, f7,  f8,  f9
  fmadd.s f23, f8,  f9,  f10
  fmadd.s f24, f9,  f10, f11
  # fmsub x 25
  fmsub.s f25, f10, f11, f12
  fmsub.s f26, f11, f12, f13
  fmsub.s f27, f12, f13, f14
  fmsub.s f28, f13, f14, f15
  fmsub.s f29, f14, f15, f0

  fmsub.s f30, f15, f0, f1
  fmsub.s f31, f0, f1, f2
  fmsub.s f16, f1, f2, f3
  fmsub.s f17, f2, f3, f4
  fmsub.s f18, f3, f4, f5

  fmsub.s f19, f4, f5, f6
  fmsub.s f20, f5, f6, f7
  fmsub.s f21, f6, f7, f8
  fmsub.s f22, f7, f8, f9
  fmsub.s f23, f8, f9, f10

  fmsub.s f24, f9, f10, f11
  fmsub.s f25, f10, f11, f12
  fmsub.s f26, f11, f12, f13
  fmsub.s f27, f12, f13, f14
  fmsub.s f28, f13, f14, f15

  fmsub.s f29, f14, f15, f0
  fmsub.s f30, f15, f0, f1
  fmsub.s f31, f0, f1, f2
  fmsub.s f16, f1, f2, f3
  fmsub.s f17, f2, f3, f4
  # fnmadd x 25 
  fnmadd.s f18, f3, f4, f5
  fnmadd.s f19, f4, f5, f6
  fnmadd.s f20, f5, f6, f7
  fnmadd.s f21, f6, f7, f8
  fnmadd.s f22, f7, f8, f9

  fnmadd.s f23, f8, f9, f10
  fnmadd.s f24, f9, f10, f11
  fnmadd.s f25, f10, f11, f12
  fnmadd.s f26, f11, f12, f13
  fnmadd.s f27, f12, f13, f14

  fnmadd.s f28, f13, f14, f15
  fnmadd.s f29, f14, f15, f0
  fnmadd.s f30, f15, f0, f1
  fnmadd.s f31, f0, f1, f2
  fnmadd.s f16, f1, f2, f3

  fnmadd.s f17, f2, f3, f4
  fnmadd.s f18, f3, f4, f5
  fnmadd.s f19, f4, f5, f6
  fnmadd.s f20, f5, f6, f7
  fnmadd.s f21, f6, f7, f8

  fnmadd.s f22, f7, f8, f9
  fnmadd.s f23, f8, f9, f10
  fnmadd.s f24, f9, f10, f11
  fnmadd.s f25, f10, f11, f12
  fnmadd.s f26, f11, f12, f13
  # fnmsub x 25
  fnmsub.s f27, f12, f13, f14
  fnmsub.s f28, f13, f14, f15
  fnmsub.s f29, f14, f15, f0
  fnmsub.s f30, f15, f0, f1
  fnmsub.s f31, f0, f1, f2

  fnmsub.s f16, f1, f2, f3
  fnmsub.s f17, f2, f3, f4
  fnmsub.s f18, f3, f4, f5
  fnmsub.s f19, f4, f5, f6
  fnmsub.s f20, f5, f6, f7

  fnmsub.s f21, f6, f7, f8
  fnmsub.s f22, f7, f8, f9
  fnmsub.s f23, f8, f9, f10
  fnmsub.s f24, f9, f10, f11
  fnmsub.s f25, f10, f11, f12

  fnmsub.s f26, f11, f12, f13
  fnmsub.s f27, f12, f13, f14
  fnmsub.s f28, f13, f14, f15
  fnmsub.s f29, f14, f15, f0
  fnmsub.s f30, f15, f0, f1

  fnmsub.s f31, f0, f1, f2
  fnmsub.s f16, f1, f2, f3
  fnmsub.s f17, f2, f3, f4
  fnmsub.s f18, f3, f4, f5
  fnmsub.s f19, f4, f5, f6
  bsg_asm_saif_end




pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
