#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define N 256
#define ANSWER 32640

.section .dram, "aw"
  float_dram_arr: .space (N*4)

.text
bsg_asm_init_regfile

// initialize data in DRAM
li t0, 0
li t1, N
la t2, float_dram_arr

init_loop:
  fcvt.s.w f0, t0 
  fsw f0, 0(t2)
  addi t0, t0, 1
  addi t2, t2, 4
  bne t0, t1, init_loop
  

// reduce the array
li t0, 0
li t1, N
la t2, float_dram_arr
reduction_loop:
  flw f0, 0(t2)
  flw f1, 4(t2)
  flw f2, 8(t2)
  flw f3, 12(t2)
  flw f4, 16(t2)
  flw f5, 20(t2)
  flw f6, 24(t2)
  flw f7, 28(t2)
  flw f8, 32(t2)
  flw f9, 36(t2)
  flw f10, 40(t2)
  flw f11, 44(t2)
  flw f12, 48(t2)
  flw f13, 52(t2)
  flw f14, 56(t2)
  flw f15, 60(t2)
  fadd.s f16, f16, f0
  fadd.s f17, f17, f1
  fadd.s f18, f18, f2
  fadd.s f19, f19, f3
  fadd.s f20, f20, f4
  fadd.s f21, f21, f5
  fadd.s f22, f22, f6
  fadd.s f23, f23, f7
  fadd.s f24, f24, f8
  fadd.s f25, f25, f9
  fadd.s f26, f26, f10
  fadd.s f27, f27, f11
  fadd.s f28, f28, f12
  fadd.s f29, f29, f13
  fadd.s f30, f30, f14
  fadd.s f31, f31, f15
  addi t0, t0, 16
  addi t2, t2, (16*4)
  bne t0, t1, reduction_loop

reduction_end:
  fadd.s f16, f16, f24
  fadd.s f17, f17, f25
  fadd.s f18, f18, f26
  fadd.s f19, f19, f27
  fadd.s f20, f20, f28
  fadd.s f21, f21, f29
  fadd.s f22, f22, f30
  fadd.s f23, f23, f31

  fadd.s f16, f16, f20
  fadd.s f17, f17, f21
  fadd.s f18, f18, f22
  fadd.s f19, f19, f23

  fadd.s f16, f16, f18
  fadd.s f17, f17, f19

  fadd.s f16, f16, f17

// compare f16 with the answer
  li t0, ANSWER
  fcvt.s.w f0, t0
  feq.s t0, f16, f0
  beq t0, x0, fail

pass:
  bsg_asm_finish(IO_X_INDEX,0)
pass_loop:
  beq x0, x0, pass_loop 
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop 
