#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.data
  float_dmem_arr: .space 64 // array of 16 floats

.section .dram, "aw"
  float_dram_arr: .space 64

.text
  bsg_asm_init_regfile



_test1:
  li t0, 0x3a83126f // 0.001
  li t1, 0x3b03126f // 0.002
  li t2, 0x3f000000 // 0.5
  fmv.s.x f0, t0
  fmv.s.x f1, t1
  fmv.s.x f2, t2

  fnmadd.s f3, f0, f1, f2 // should be -(0.001*0.002)+0.5 =  0.499998
  fnmsub.s f4, f0, f1, f2 // should be -(0.001*0.002)-0.5 = -0.500002
  fmv.x.s t3, f3  
  fmv.x.s t4, f4
  li t5, 0x3effffbd
  li t6, 0xbf000022
  bne t3, t5, fail
  bne t4, t6, fail




pass:
  bsg_asm_finish(IO_X_INDEX, 0)

pass_loop:
  beq x0, x0, pass_loop

fail:
  bsg_asm_fail(IO_X_INDEX, 0)

fail_loop:
  beq x0, x0, fail_loop

