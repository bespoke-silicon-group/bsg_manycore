#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile
  lui x5, 0
  lui x6, 0
  lui x7, 0
  lui x8, 0
  lui x9, 0
  lui x10,0
  lui x11,0
  lui x12,0
  lui x13,0
  lui x14,0
  lui x15,0
  lui x16,0
  lui x17,0
  lui x18,0
  lui x19,0
  lui x20,0
  lui x21,0
  lui x22,0
  lui x23,0
  lui x24,0
  lui x25,0
  lui x26,0
  lui x27,0
  lui x28,0
  lui x29,0
  lui x30,0
  lui x31,0
  // saif start
  bsg_asm_saif_start
  add s6,s9,s10
  add s7,s11,t3
  add s8,t4,t5
  add s9,t6,t0
  add t3,t0,t1
  add t4,t2,s0
  add t5,s1,a0
  add t6,a1,a2
  add t0,s7,s8
  add t1,s9,s10
  add t2,s11,t3
  add s0,t4,t5
  add s1,t6,t0
  add a2,t0,t1
  add a3,t2,s0
  add a4,s1,a0
  add a5,a1,a2
  add a6,a3,a4
  add a7,a5,a6
  add s2,a7,s2
  add s3,s3,s4
  add s4,s5,s6
  add s5,s7,s8
  add s6,s9,s10
  add s7,s11,t3
  add s8,t4,t5
  add s9,t6,t0
  add t3,t0,t1
  add t4,t2,s0
  add t5,s1,a0
  add t6,a1,a2
  add t0,s7,s8
  add t1,s9,s10
  add t2,s11,t3
  add s0,t4,t5
  add s1,t6,t0
  add a2,t0,t1
  add a3,t2,s0
  add a4,s1,a0
  add a5,a1,a2
  add a6,a3,a4
  add a7,a5,a6
  add s2,a7,s2
  add s3,s3,s4
  add s4,s5,s6
  add s5,s7,s8
  add s6,s9,s10
  add s7,s11,t3
  add s8,t4,t5
  add s9,t6,t0
  add t3,t0,t1
  add t4,t2,s0
  add t5,s1,a0
  add t6,a1,a2
  add t0,s7,s8
  add t1,s9,s10
  add t2,s11,t3
  add s0,t4,t5
  add s1,t6,t0
  add a2,t0,t1
  add a3,t2,s0
  add a4,s1,a0
  add a5,a1,a2
  add a6,a3,a4
  add a7,a5,a6
  add s2,a7,s2
  add s3,s3,s4
  add s4,s5,s6
  add s5,s7,s8
  add s6,s9,s10
  add s7,s11,t3
  add s8,t4,t5
  add s9,t6,t0
  add t3,t0,t1
  add t4,t2,s0
  add t5,s1,a0
  add t6,a1,a2
  add t0,s7,s8
  add t1,s9,s10
  add t2,s11,t3
  add s0,t4,t5
  add s1,t6,t0
  add a2,t0,t1
  add a3,t2,s0
  add a4,s1,a0
  add a5,a1,a2
  add a6,a3,a4
  add a7,a5,a6
  add s2,a7,s2
  add s3,s3,s4
  add s4,s5,s6
  add s5,s7,s8
  add s6,s9,s10
  add s7,s11,t3
  add s8,t4,t5
  add s9,t6,t0
  add t3,t0,t1
  add t4,t2,s0
  add t5,s1,a0
  add t6,a1,a2
  // saif end
  bsg_asm_saif_end


pass:
  bsg_asm_finish(IO_X_INDEX, 0)

pass_loop:
  beq x0, x0, pass_loop

fail:
  bsg_asm_fail(IO_X_INDEX, 0)

fail_loop:
  beq x0, x0, fail_loop
