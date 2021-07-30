#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile

  li x5 ,0xffffffff
  li x6 ,0xffffffff
  li x7 ,0xffffffff
  li x8 ,0xffffffff
  li x9 ,0xffffffff
  li x10,0xffffffff
  li x11,0xffffffff
  li x12,0xffffffff
  li x13,0xffffffff
  li x14,0xffffffff
  li x15,0xffffffff
  li x16,0xffffffff
  li x17,0xffffffff
  li x18,0xffffffff
  li x19,0xffffffff
  li x20,0xffffffff
  li x21,0xffffffff
  li x22,0xffffffff
  li x23,0xffffffff
  li x24,0xffffffff
  li x25,0xffffffff
  li x26,0xffffffff
  li x27,0xffffffff
  li x28,0xffffffff
  li x29,0xffffffff
  li x30,0xffffffff
  li x31,0xffffffff
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
