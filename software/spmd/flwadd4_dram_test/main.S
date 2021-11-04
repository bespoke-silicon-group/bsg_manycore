#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define N 8

.section .dram, "aw"
  float_arr: .space (N*4)

.text
  bsg_asm_init_regfile 


init_start:
  li t0, 0
  li t1, N
  la t2, float_arr

// initilize float_arr with 0,1,2...N-1
init_loop:
  fcvt.s.w f0, t0
  fsw f0, 0(t2)
  addi t2, t2, 4
  addi t0, t0, 1
  bne t0, t1, init_loop
   
test0:
  la t0, float_arr
  li t1, 4
  li t2, -1
  li t3, -1
  li t4, -1
  li t5, -1
  flwadd4 f0, t0, t1
  
  // validate f0, f1, f2, f3
  fcvt.w.s t2, f0
  fcvt.w.s t3, f1
  fcvt.w.s t4, f2
  fcvt.w.s t5, f3
  li s0, 0
  li s1, 1
  li s2, 2
  li s3, 3
  bne t2, s0, fail
  bne t3, s1, fail
  bne t4, s2, fail
  bne t5, s3, fail
  
  // validate t0
  la t1, float_arr
  addi t1, t1, 16
  bne t0, t1, fail

test1:
  la t0, float_arr
  li t1, 4
  li t2, -1
  li t3, -1
  li t4, -1
  li t5, -1
  flwadd4 f0, t0, t1
  flwadd4 f4, t0, t1
  
  // validate f0, f1, f2, f3
  fcvt.w.s t2, f0
  fcvt.w.s t3, f1
  fcvt.w.s t4, f2
  fcvt.w.s t5, f3
  li s0, 0
  li s1, 1
  li s2, 2
  li s3, 3
  bne t2, s0, fail
  bne t3, s1, fail
  bne t4, s2, fail
  bne t5, s3, fail
  // validate f4, f5, f6, f7
  fcvt.w.s t2, f4
  fcvt.w.s t3, f5
  fcvt.w.s t4, f6
  fcvt.w.s t5, f7
  li s0, 4
  li s1, 5
  li s2, 6
  li s3, 7
  bne t2, s0, fail
  bne t3, s1, fail
  bne t4, s2, fail
  bne t5, s3, fail
  
  // validate t0
  la t1, float_arr
  addi t1, t1, 32
  bne t0, t1, fail





pass:
  bsg_asm_finish(IO_X_INDEX,0)
pass_loop:
  beq x0, x0, pass_loop 
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop 
