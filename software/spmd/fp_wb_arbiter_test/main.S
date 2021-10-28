//  Test description:
//  This test exercises tests the fp_wb_arbiter module by maximizing the fp writeback bandwidth.




#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define N 64
#define ANSWER 85344

.data
  float_dmem_arr: .space (N*4)

.section .dram, "aw"
  float_dram_arr: .space (N*4)

.text
  bsg_asm_init_regfile

// initialize data
li t0, 0
li t1, N
la t2, float_dmem_arr
la t3, float_dram_arr

// vectors in dmem and dram are initialized with float values ranging 0.0, 1.0, ..., N
init_loop:
  fcvt.s.w f0, t0
  fsw f0, 0(t2)
  fsw f0, 0(t3)
  addi t0, t0, 1
  addi t2, t2, 4
  addi t3, t3, 4
  bne t0, t1, init_loop

// both f23, f27 are set to 100, which will be repeatedly used to calculate f23/f27 (=1.0), using fdiv.
init_end:
  li t0, 100
  fcvt.s.w f23, t0
  fcvt.s.w f27, t0

// main loop
li t0, 0
li t1, N
la t2, float_dram_arr
la t3, float_dmem_arr

main_loop:
  // we launch fdiv at the start of the main loop.
  // f31 should always result in 1.0
  fdiv.s f31, f23, f27
  // load dram data into  f0, f4, ..., f28
  flw f0,    0(t2)
  flw f4,    4(t2)
  flw f8,    8(t2)
  flw f12,  12(t2)
  flw f16,  16(t2)
  flw f20,  20(t2)
  flw f24,  24(t2)
  flw f28,  28(t2)
  // load dmem data into  f1, f5, ..., f29
  flw f1,    0(t3)
  flw f5,    4(t3)
  flw f9,    8(t3)
  flw f13,  12(t3)
  flw f17,  16(t3)
  flw f21,  20(t3)
  flw f25,  24(t3)
  flw f29,  28(t3)
  // do element-wise multiply, and accumulate results in f2, f6, ..., f30
  fmadd.s f2,  f0,  f1,  f2
  fmadd.s f6,  f4,  f5,  f6
  fmadd.s f10, f8,  f9,  f10
  fmadd.s f14, f12, f13, f14
  fmadd.s f18, f16, f17, f18
  fmadd.s f22, f20, f21, f22
  fmadd.s f26, f24, f25, f26
  fmadd.s f30, f28, f29, f30
  addi t0, t0, 8
  addi t2, t2, 32
  addi t3, t3, 32
  bne t0, t1, main_loop

// verify
main_loop_end:
  // sum up all accumulation and multiply by f31
  fadd.s f7,  f2,  f18
  fadd.s f11, f6,  f22
  fadd.s f15, f10, f26
  fadd.s f19, f14, f30

  fadd.s f7,  f7,  f11
  fadd.s f11, f15, f19

  fadd.s f7,  f7,  f11

  fmul.s f7, f7, f31

  fcvt.w.s t0, f7
  li t1, ANSWER
  bne t0, t1, fail


pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop

