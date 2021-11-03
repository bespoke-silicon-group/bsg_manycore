#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define N 8

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
   
test0:
  la t0, float_dmem_arr
  li t1, 4
  li t2, -1
  bsg_asm_flwadd(0, 5, 6)   // rd=f0, rs1=x5 (t0), rs2=x6 (t1)
  
  // validate f0
  fcvt.w.s t2, f0
  bne t2, x0, fail
  
  // validate t0
  la t1, float_dmem_arr
  addi t1, t1, 4
  bne t0, t1, fail

test1:
  la t0, float_dmem_arr
  li t1, 4
  bsg_asm_flwadd(0, 5, 6)   // rd=f0, rs1=x5 (t0), rs2=x6 (t1)
  bsg_asm_flwadd(1, 5, 6)   // rd=f1, rs1=x5 (t0), rs2=x6 (t1)
  
  // validate f0, f1
  fcvt.w.s t2, f0
  fcvt.w.s t3, f1
  add t4, t2, t3
  li t5, 1
  bne t4, t5, fail

  // validate t0
  la t2, float_dmem_arr
  addi t2, t2, 8
  bne t2, t0, fail

test2:
  la t0, float_dmem_arr
  li t1, 4
  bsg_asm_flwadd(0, 5, 6)   // rd=f0, rs1=x5 (t0), rs2=x6 (t1)
  bsg_asm_flwadd(1, 5, 6)   // rd=f1, rs1=x5 (t0), rs2=x6 (t1)
  bsg_asm_flwadd(2, 5, 6)   // rd=f2, rs1=x5 (t0), rs2=x6 (t1)

  // validate f0, f1, f2
  fcvt.w.s t2, f0
  fcvt.w.s t3, f1
  fcvt.w.s t4, f2
  add t2, t2, t3
  add t2, t2, t4
  li t5, 3
  bne t5, t2, fail

  // validate t0
  la t2, float_dmem_arr
  addi t2, t2, 12
  bne t2, t0, fail
  

test3:
  la t0, float_dmem_arr
  li t1, 4
  bsg_asm_flwadd(0, 5, 6)   // rd=f0, rs1=x5 (t0), rs2=x6 (t1)
  bsg_asm_flwadd(1, 5, 6)   // rd=f1, rs1=x5 (t0), rs2=x6 (t1)
  bsg_asm_flwadd(2, 5, 6)   // rd=f2, rs1=x5 (t0), rs2=x6 (t1)
  bsg_asm_flwadd(3, 5, 6)   // rd=f3, rs1=x5 (t0), rs2=x6 (t1)

  // validate f0, f1, f2, f3
  fcvt.w.s t2, f0
  fcvt.w.s t3, f1
  fcvt.w.s t4, f2
  fcvt.w.s t5, f3
  add t2, t2, t3
  add t2, t2, t4
  add t2, t2, t5
  li t6, 6
  bne t6, t2, fail

  // validate t0
  la t2, float_dmem_arr
  addi t2, t2, 16
  bne t2, t0, fail

pass:
  bsg_asm_finish(IO_X_INDEX,0)
pass_loop:
  beq x0, x0, pass_loop 
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop 
