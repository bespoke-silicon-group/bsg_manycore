#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile
  li x1, 82
  li x2, -118282
  li x3, 21992
  li x4, 371
  li x5, 319282
  li x6, -568955
  li x7, 99209
  li x8, 4
  li x9, -384387
  li x10, -697988
  li x11, 8726
  li x12, 419706
  li x13, 20
  li x14, -535533
  li x15, 1284712
  li x16, 77883150
  
  fcvt.s.w f0, x1
  fcvt.s.w f1, x2
  fcvt.s.w f2, x3
  fcvt.s.w f3, x4
  fcvt.s.w f4, x5
  fcvt.s.w f5, x6
  fcvt.s.w f6, x7
  fcvt.s.w f7, x8
  fcvt.s.w f8, x9
  fcvt.s.w f9, x10
  fcvt.s.w f10, x11
  fcvt.s.w f11, x12
  fcvt.s.w f12, x13
  fcvt.s.w f13, x14
  fcvt.s.w f14, x15
  fcvt.s.w f15, x16

  // saif start
  bsg_asm_saif_start

  fdiv.s f17, f4, f10
  fdiv.s f16, f13, f7
  fdiv.s f29, f6, f9
  fdiv.s f26, f12, f11
  fdiv.s f30, f14, f0
  fdiv.s f21, f2, f4
  fdiv.s f19, f7, f13
  fdiv.s f18, f9, f1
  fdiv.s f17, f15, f1
  fdiv.s f21, f8, f7
  fdiv.s f28, f4, f7
  fdiv.s f30, f3, f15
  fdiv.s f30, f10, f11
  fdiv.s f27, f7, f5
  fdiv.s f28, f7, f0
  fdiv.s f20, f6, f9
  fdiv.s f22, f15, f11
  fdiv.s f16, f0, f7
  fdiv.s f18, f0, f0
  fdiv.s f23, f8, f10
  fdiv.s f16, f3, f13
  fdiv.s f16, f13, f14
  fdiv.s f28, f6, f6
  fdiv.s f27, f0, f5
  fdiv.s f22, f4, f15
  fdiv.s f19, f4, f14
  fdiv.s f30, f14, f6
  fdiv.s f22, f4, f5
  fdiv.s f21, f2, f14
  fdiv.s f29, f3, f3
  fdiv.s f24, f9, f12
  fdiv.s f22, f8, f8
  fdiv.s f31, f8, f13
  fdiv.s f29, f5, f8
  fdiv.s f30, f2, f8
  fdiv.s f18, f4, f9
  fdiv.s f17, f0, f0
  fdiv.s f28, f11, f13
  fdiv.s f24, f14, f1
  fdiv.s f30, f5, f3
  fdiv.s f27, f8, f1
  fdiv.s f22, f2, f11
  fdiv.s f31, f6, f13
  fdiv.s f22, f15, f3
  fdiv.s f19, f0, f3
  fdiv.s f17, f12, f10
  fdiv.s f26, f1, f2
  fdiv.s f28, f12, f0
  fdiv.s f27, f0, f3
  fdiv.s f31, f10, f2
  fdiv.s f17, f9, f14
  fdiv.s f25, f11, f11
  fdiv.s f18, f15, f8
  fdiv.s f26, f1, f12
  fdiv.s f25, f1, f14
  fdiv.s f20, f11, f9
  fdiv.s f29, f15, f0
  fdiv.s f22, f13, f3
  fdiv.s f27, f4, f4
  fdiv.s f29, f10, f2
  fdiv.s f22, f12, f13
  fdiv.s f31, f8, f4
  fdiv.s f28, f10, f12
  fdiv.s f29, f12, f4
  fdiv.s f26, f7, f4
  fdiv.s f19, f14, f13
  fdiv.s f30, f10, f14
  fdiv.s f28, f6, f12
  fdiv.s f24, f3, f6
  fdiv.s f19, f8, f13
  fdiv.s f27, f0, f12
  fdiv.s f28, f10, f13
  fdiv.s f17, f12, f2
  fdiv.s f25, f8, f11
  fdiv.s f21, f9, f6
  fdiv.s f20, f2, f13
  fdiv.s f31, f9, f8
  fdiv.s f28, f0, f2
  fdiv.s f31, f7, f11
  fdiv.s f19, f4, f6
  fdiv.s f23, f11, f5
  fdiv.s f20, f12, f10
  fdiv.s f18, f9, f9
  fdiv.s f18, f10, f10
  fdiv.s f26, f10, f13
  fdiv.s f17, f12, f1
  fdiv.s f23, f1, f1
  fdiv.s f28, f0, f14
  fdiv.s f23, f4, f7
  fdiv.s f30, f12, f9
  fdiv.s f19, f6, f6
  fdiv.s f24, f9, f1
  fdiv.s f24, f6, f13
  fdiv.s f21, f12, f10
  fdiv.s f26, f3, f8
  fdiv.s f16, f6, f8
  fdiv.s f26, f12, f11
  fdiv.s f21, f9, f8
  fdiv.s f18, f15, f11
  fdiv.s f17, f10, f6


  // saif end
  bsg_asm_saif_end


pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
