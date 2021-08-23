#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile

  li x5 ,0x011fe39c
  li x6 ,0x03295e93
  li x7 ,0x312896f8
  li x8 ,0x75455f11
  li x9 ,0x2dee2161
  li x10,0x7138813b
  li x11,0x000b5c8b
  li x12,0x011edcb2
  li x13,0x144144dd
  li x14,0xcfe72316
  li x15,0x7552b181
  li x16,0x5e89a000
  li x17,0x234f0591
  li x18,0x1234687f
  li x19,0xaa123976
  li x20,0x12cd3000
  li x21,0x6233c888
  li x22,0x6ebd9901
  li x23,0xcf000011
  li x24,0xf49fb666
  li x25,0xe10b6334
  li x26,0x2288f000
  li x27,0xcfa37bb3
  li x28,0xd7341635
  li x29,0xcca30000
  li x30,0xfd95d442
  li x31,0x7c8e3113
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
