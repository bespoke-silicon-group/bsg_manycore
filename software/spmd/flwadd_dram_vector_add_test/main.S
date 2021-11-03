// Do vector in DRAM using flwadd

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
  flwadd f0, t0, t4
  flwadd f1, t1, t4
  fadd.s f31, f0, f1
  fsw f31, 0(t2)
  addi t2, t2, 4
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
  
// test1 (unroll by 2)
test1_init:
  la t0, float_arr1
  la t1, float_arr2
  la t2, float_arr3
  addi t3, t0, (4*N)
  li t4, 4  // stride

test1_loop:
  flwadd f0, t0, t4
  flwadd f1, t0, t4
  flwadd f2, t1, t4
  flwadd f3, t1, t4
  fadd.s f30, f0, f2
  fadd.s f31, f1, f3
  fsw f30, 0(t2)
  fsw f31, 4(t2)
  addi t2, t2, 8
  bne t0, t3, test1_loop

test1_validate_init:
  la t0, float_arr3
  li t1, 0
  li t2, N
  li t3, 3

test1_validate_loop:
  flw f0, 0(t0)
  fcvt.w.s t4, f0
  mul t5, t1, t3
  bne t5, t4, fail
  addi t1, t1, 1
  addi t0, t0, 4
  bne t1, t2, test1_validate_loop

// test2 (unroll by 4)
test2_init:
  la t0, float_arr1
  la t1, float_arr2
  la t2, float_arr3
  addi t3, t0, (4*N)
  li t4, 4  // stride

test2_loop:
  flwadd f0, t0, t4
  flwadd f1, t0, t4
  flwadd f2, t0, t4
  flwadd f3, t0, t4
  flwadd f4, t1, t4
  flwadd f5, t1, t4
  flwadd f6, t1, t4
  flwadd f7, t1, t4
  fadd.s f28, f0, f4
  fadd.s f29, f1, f5
  fadd.s f30, f2, f6
  fadd.s f31, f3, f7
  fsw f28, 0(t2)
  fsw f29, 4(t2)
  fsw f30, 8(t2)
  fsw f31, 12(t2)
  addi t2, t2, 16
  bne t0, t3, test2_loop

test2_validate_init:
  la t0, float_arr3
  li t1, 0
  li t2, N
  li t3, 3

test2_validate_loop:
  flw f0, 0(t0)
  fcvt.w.s t4, f0
  mul t5, t1, t3
  bne t5, t4, fail
  addi t1, t1, 1
  addi t0, t0, 4
  bne t1, t2, test2_validate_loop


// test3 (unroll by 8)
test3_init:
  la t0, float_arr1
  la t1, float_arr2
  la t2, float_arr3
  addi t3, t0, (4*N)
  li t4, 4  // stride

test3_loop:
  flwadd f0, t0, t4
  flwadd f1, t0, t4
  flwadd f2, t0, t4
  flwadd f3, t0, t4
  flwadd f4, t0, t4
  flwadd f5, t0, t4
  flwadd f6, t0, t4
  flwadd f7, t0, t4

  flwadd f8, t1, t4
  flwadd f9, t1, t4
  flwadd f10, t1, t4
  flwadd f11, t1, t4
  flwadd f12, t1, t4
  flwadd f13, t1, t4
  flwadd f14, t1, t4
  flwadd f15, t1, t4

  fadd.s f24, f0, f8
  fadd.s f25, f1, f9
  fadd.s f26, f2, f10
  fadd.s f27, f3, f11
  fadd.s f28, f4, f12
  fadd.s f29, f5, f13
  fadd.s f30, f6, f14
  fadd.s f31, f7, f15

  fsw f24, 0(t2)
  fsw f25, 4(t2)
  fsw f26, 8(t2)
  fsw f27, 12(t2)
  fsw f28, 16(t2)
  fsw f29, 20(t2)
  fsw f30, 24(t2)
  fsw f31, 28(t2)
  addi t2, t2, 32
  bne t0, t3, test3_loop

test3_validate_init:
  la t0, float_arr3
  li t1, 0
  li t2, N
  li t3, 3

test3_validate_loop:
  flw f0, 0(t0)
  fcvt.w.s t4, f0
  mul t5, t1, t3
  bne t5, t4, fail
  addi t1, t1, 1
  addi t0, t0, 4
  bne t1, t2, test3_validate_loop



// End of test
pass:
  bsg_asm_finish(IO_X_INDEX,0)
pass_loop:
  beq x0, x0, pass_loop 
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop 
