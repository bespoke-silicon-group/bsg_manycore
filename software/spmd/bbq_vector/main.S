#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"
#define N 1024

.text
  // initialize
  bsg_asm_init_regfile
  li t0, 0x3f800000 
  fmv.s.x f0, t0
  fmv.s.x f8, t0
  fmv.s.x f16, t0
  fmv.s.x f24, t0
  li t0, 0x3de56042
  fmv.s.x f1, t0
  fmv.s.x f9, t0
  fmv.s.x f17, t0
  fmv.s.x f25, t0
  li t0, 0xc61c4c00
  fmv.s.x f2, t0
  fmv.s.x f10, t0
  fmv.s.x f18, t0
  fmv.s.x f26, t0
  li t0, 0xb9adbfc1
  fmv.s.x f3, t0
  fmv.s.x f11, t0
  fmv.s.x f19, t0
  fmv.s.x f27, t0
  li t0, 0x4ab6997e
  fmv.s.x f4, t0
  fmv.s.x f12, t0
  fmv.s.x f20, t0
  fmv.s.x f28, t0
  li t0, 0x41700000
  fmv.s.x f5, t0
  fmv.s.x f13, t0
  fmv.s.x f21, t0
  fmv.s.x f29, t0
  li t0, 0xc2c80000
  fmv.s.x f6, t0
  fmv.s.x f14, t0
  fmv.s.x f22, t0
  fmv.s.x f30, t0
  li t0, 0xc61d8c00
  fmv.s.x f7, t0
  fmv.s.x f15, t0
  fmv.s.x f23, t0
  fmv.s.x f31, t0
  
// initialize DMEM
// t0 = how many times to loop?
li t0, 4
li t1, 0
loop:
  fmadd.s f0, f0, f1, f2
  fmadd.s f31, f3, f4, f5
  fmadd.s f1, f6, f7, f0
  fmadd.s f30, f1, f2, f3
  fmadd.s f2, f4, f5, f6
  fmadd.s f29, f7, f0, f1
  fmadd.s f3, f2, f3, f4
  fmadd.s f28, f5, f6, f7
  fsw f0,  0(t1)
  fsw f31, 700(t1)
  fsw f1,  200(t1)
  fsw f30, 300(t1)
  fsw f2,  500(t1)
  fsw f29, 400(t1)
  fsw f3,  600(t1)
  fsw f28, 100(t1)
  addi t1, t1, 4

  fmadd.s f4,  f8,  f9,  f10
  fmadd.s f27, f11, f12, f13
  fmadd.s f5,  f14, f15, f8
  fmadd.s f26, f9,  f10, f11
  fmadd.s f6,  f12, f13, f14
  fmadd.s f25, f15, f8,  f9
  fmadd.s f7,  f10, f11, f12
  fmadd.s f24, f13, f14, f15
  fsw f4,  0(t1)
  fsw f27, 700(t1)
  fsw f5,  200(t1)
  fsw f26, 300(t1)
  fsw f6,  500(t1)
  fsw f25, 400(t1)
  fsw f7,  600(t1)
  fsw f24, 100(t1)
  addi t1, t1, 4

  fmadd.s f8,  f16, f17, f18
  fmadd.s f23, f19, f20, f21
  fmadd.s f9,  f22, f23, f16
  fmadd.s f22, f17, f18, f19
  fmadd.s f10, f20, f21, f22
  fmadd.s f21, f23, f16, f17
  fmadd.s f11, f18, f19, f20
  fmadd.s f20, f21, f22, f23
  fsw f8,  0(t1)
  fsw f23, 700(t1)
  fsw f9,  200(t1)
  fsw f22, 300(t1)
  fsw f10, 500(t1)
  fsw f21, 400(t1)
  fsw f11, 600(t1)
  fsw f20, 100(t1)
  addi t1, t1, 4

  fmadd.s f12, f24, f25, f26
  fmadd.s f23, f27, f28, f29
  fmadd.s f13, f30, f31, f24
  fmadd.s f22, f25, f26, f27
  fmadd.s f14, f28, f29, f30
  fmadd.s f21, f31, f24, f25
  fmadd.s f15, f26, f27, f28
  fmadd.s f20, f29, f30, f31
  fsw f12, 0(t1)
  fsw f23, 700(t1)
  fsw f13, 200(t1)
  fsw f22, 300(t1)
  fsw f14, 500(t1)
  fsw f21, 400(t1)
  fsw f15, 600(t1)
  fsw f20, 100(t1)
  addi t1, t1, 4

  addi t0, t0, -1
  bne t0, x0, loop


pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
  nop
  nop
