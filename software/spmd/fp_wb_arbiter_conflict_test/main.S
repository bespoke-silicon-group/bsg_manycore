//  Test description:
//  This test exercises the conflict to the same write bank.



#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define N 128
#define ANSWER 690880

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


// load dmem vector and dram vector four elements at a time to the same bank.
// dmem vector = f0, f4, f8, f12
// dram vector = f16, f20, f24, f28
// Do element-wise multiply and accumulate in another bank (f1, f5, f9, f13)
li t0, 0
li t1, N
la t2, float_dmem_arr
la t3, float_dram_arr

loop0:
  flw f16,  0(t3)
  flw f20,  4(t3)
  flw f24,  8(t3)
  flw f28, 12(t3)
  flw f0,   0(t2)
  flw f4,   4(t2)
  flw f8,   8(t2)
  flw f12, 12(t2)
  fmadd.s f1,  f0,  f16, f1
  fmadd.s f5,  f4,  f20, f5
  fmadd.s f9,  f8,  f24, f9
  fmadd.s f13, f12, f28, f13
  addi t0, t0, 4
  addi t2, t2, 16
  addi t3, t3, 16
  bne t0, t1, loop0

loop_end:
  fadd.s f31, f31, f1
  fadd.s f31, f31, f5
  fadd.s f31, f31, f9
  fadd.s f31, f31, f13
  fcvt.w.s t0, f31
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

