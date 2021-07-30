#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile

  lui x5,0xe39c
  lui x6,0x95e93
  lui x7,0x896f8
  lui x8,0x55f11
  lui x9,0xe2161
  lui x10,0x8813b
  lui x11,0xb5c8b
  lui x12,0xedcb2
  lui x13,0x144dd
  lui x14,0x72316
  lui x15,0x2b181
  lui x16,0x5e89a
  lui x17,0xf0591
  lui x18,0x687f
  lui x19,0x976
  lui x20,0x12cd3
  lui x21,0x6233c
  lui x22,0x6ebd9
  lui x23,0xcf00
  lui x24,0xf49fb
  lui x25,0xe10b6
  lui x26,0x2288f
  lui x27,0xcfa37
  lui x28,0xd7341
  lui x29,0xcca30
  lui x30,0xfd95d
  lui x31,0x7c8e3
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
