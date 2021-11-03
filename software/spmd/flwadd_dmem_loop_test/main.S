// calculate sum of integers from 0 to N-1 using flwadd

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define N 120
#define ANSWER 7140

.data
  float_dmem_arr: .space (N*4)

.text
  bsg_asm_init_regfile 


init_start:
  li t0, 0
  li t1, N
  la t2, float_dmem_arr

init_loop:
  fcvt.s.w f0, t0
  fsw f0, 0(t2)
  addi t2, t2, 4
  addi t0, t0, 1
  bne t0, t1, init_loop

// TEST0 unroll by 1   
test0:
  la t0, float_dmem_arr
  addi t1, t0, (N*4)
  li t2, 4
  fcvt.s.w f0, x0

test0_loop:
  bsg_asm_flwadd(1, 5, 7)   // flwadd f1, t0, t2
  fadd.s f0, f0, f1
  bne t0, t1, test0_loop

  // validate test0
  fcvt.w.s t0, f0
  li t1, ANSWER
  bne t0, t1, fail

// TEST1 unroll by 2
test1:
  la t0, float_dmem_arr
  addi t1, t0, (N*4)
  li t2, 4
  fcvt.s.w f0, x0

test1_loop:
  bsg_asm_flwadd(1, 5, 7)   // flwadd f1, t0, t2
  bsg_asm_flwadd(2, 5, 7)   // flwadd f2, t0, t2
  fadd.s f0, f0, f1
  fadd.s f0, f0, f2
  bne t0, t1, test1_loop

  // validate test1
  fcvt.w.s t0, f0
  li t1, ANSWER
  bne t0, t1, fail


// TEST2 unroll by 3
test2:
  la t0, float_dmem_arr
  addi t1, t0, (N*4)
  li t2, 4
  fcvt.s.w f0, x0

test2_loop:
  bsg_asm_flwadd(1, 5, 7)   // flwadd f1, t0, t2
  bsg_asm_flwadd(2, 5, 7)   // flwadd f2, t0, t2
  bsg_asm_flwadd(3, 5, 7)   // flwadd f3, t0, t2
  fadd.s f0, f0, f1
  fadd.s f0, f0, f2
  fadd.s f0, f0, f3
  bne t0, t1, test2_loop

  // validate test2
  fcvt.w.s t0, f0
  li t1, ANSWER
  bne t0, t1, fail


// TEST3 unroll by 4
test3:
  la t0, float_dmem_arr
  addi t1, t0, (N*4)
  li t2, 4
  fcvt.s.w f0, x0

test3_loop:
  bsg_asm_flwadd(1, 5, 7)   // flwadd f1, t0, t2
  bsg_asm_flwadd(2, 5, 7)   // flwadd f2, t0, t2
  bsg_asm_flwadd(3, 5, 7)   // flwadd f3, t0, t2
  bsg_asm_flwadd(4, 5, 7)   // flwadd f4, t0, t2
  fadd.s f0, f0, f1
  fadd.s f0, f0, f2
  fadd.s f0, f0, f3
  fadd.s f0, f0, f4
  bne t0, t1, test3_loop

  // validate test3
  fcvt.w.s t0, f0
  li t1, ANSWER
  bne t0, t1, fail


// TEST4 unroll by 5
test4:
  la t0, float_dmem_arr
  addi t1, t0, (N*4)
  li t2, 4
  fcvt.s.w f0, x0

test4_loop:
  bsg_asm_flwadd(1, 5, 7)   // flwadd f1, t0, t2
  bsg_asm_flwadd(2, 5, 7)   // flwadd f2, t0, t2
  bsg_asm_flwadd(3, 5, 7)   // flwadd f3, t0, t2
  bsg_asm_flwadd(4, 5, 7)   // flwadd f4, t0, t2
  bsg_asm_flwadd(5, 5, 7)   // flwadd f5, t0, t2
  fadd.s f0, f0, f1
  fadd.s f0, f0, f2
  fadd.s f0, f0, f3
  fadd.s f0, f0, f4
  fadd.s f0, f0, f5
  bne t0, t1, test4_loop

  // validate test4
  fcvt.w.s t0, f0
  li t1, ANSWER
  bne t0, t1, fail


// TEST5 unroll by 6
test5:
  la t0, float_dmem_arr
  addi t1, t0, (N*4)
  li t2, 4
  fcvt.s.w f0, x0

test5_loop:
  bsg_asm_flwadd(1, 5, 7)   // flwadd f1, t0, t2
  bsg_asm_flwadd(2, 5, 7)   // flwadd f2, t0, t2
  bsg_asm_flwadd(3, 5, 7)   // flwadd f3, t0, t2
  bsg_asm_flwadd(4, 5, 7)   // flwadd f4, t0, t2
  bsg_asm_flwadd(5, 5, 7)   // flwadd f5, t0, t2
  bsg_asm_flwadd(6, 5, 7)   // flwadd f6, t0, t2
  fadd.s f0, f0, f1
  fadd.s f0, f0, f2
  fadd.s f0, f0, f3
  fadd.s f0, f0, f4
  fadd.s f0, f0, f5
  fadd.s f0, f0, f6
  bne t0, t1, test5_loop

  // validate test5
  fcvt.w.s t0, f0
  li t1, ANSWER
  bne t0, t1, fail



// End of test
pass:
  bsg_asm_finish(IO_X_INDEX,0)
pass_loop:
  beq x0, x0, pass_loop 
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop 
