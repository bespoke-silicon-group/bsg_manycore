// Do vector in DRAM using flwadd4

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define N 128
#define ANSWER 

//.data // DMEM
.section .dram, "aw"  // DRAM
  float_arr1: .space (N*4)  // vec1
  float_arr2: .space (N*4)  // vec2
  float_arr3: .space (N*4)  // vec1 + vec2

.text
  bsg_asm_init_regfile 


init_start1:
  li t0, 0
  li t1, 0
  li t2, N
  la t3, float_arr1
  la t4, float_arr2

// store 0,1,2, ~ N on float_arr1
// store 0,2,4, ~ 2N on float_arr2
init_loop:
  slli t1, t0, 1
  fcvt.s.w f0, t0
  fcvt.s.w f1, t1
  fsw f0, 0(t3)
  fsw f1, 0(t4)
  addi t0, t0, 1
  addi t3, t3, 4
  addi t4, t4, 4
  bne t0, t2, init_loop


// test0
test0_init:
  la t0, float_arr1
  la t1, float_arr2
  la t2, float_arr3
  addi t3, t0, (4*N)
  li t4, 4  // stride

test0_loop:
  flwadd4 f0, t0, t4
  flwadd4 f4, t1, t4

  fadd.s f16, f0, f4
  fadd.s f17, f1, f5
  fadd.s f18, f2, f6
  fadd.s f19, f3, f7

  fsw f16, 0(t2)
  fsw f17, 4(t2)
  fsw f18, 8(t2)
  fsw f19, 12(t2)

  addi t2, t2, 16
  bne t0, t3, test0_loop

test0_validate_init:
  la t0, float_arr3
  li t1, 0
  li t2, N
  li t3, 3

test0_validate_loop:
  flw f0, 0(t0)
  fcvt.w.s t4, f0
  mul t5, t1, t3
  bne t5, t4, fail
  addi t1, t1, 1
  addi t0, t0, 4
  bne t1, t2, test0_validate_loop
  


// End of test
pass:
  bsg_asm_finish(IO_X_INDEX,0)
pass_loop:
  beq x0, x0, pass_loop 
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop 
