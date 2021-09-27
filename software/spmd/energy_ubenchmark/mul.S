#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  bsg_asm_init_regfile

  li t0,0xe39c
  li t1,0x95e93
  li t2,0x896f8
  li s0,0x55f11
  li s1,0xe2161
  li a0,0x8813b
  li a1,0xb5c8b
  li a2,0xedcb2
  li a3,0x144dd
  li a4,0x72316
  li a5,0x2b181
  li a6,0x5e89a
  li a7,0xf0591
  li s2,0x687f
  li s3,0x976
  li s4,0x12cd3
  li s5,0x6233c
  li s6,0x6ebd9
  li s7,0xcf00
  li s8,0xf49fb
  li s9,0xe10b6
  li s10,0x2288f
  li s11,0xcfa37
  li t3,0xd7341
  li t4,0xcca30
  li t5,0xfd95d
  li t6,0x7c8e3

  bsg_asm_saif_start
  mul s6,s9,s10
  mul s7,s11,t3
  mul s8,t4,t5
  mul s9,t6,t0
  mul t3,t0,t1
  mul t4,t2,s0
  mul t5,s1,a0
  mul t6,a1,a2
  mul t0,s7,s8
  mul t1,s9,s10
  mul t2,s11,t3
  mul s0,t4,t5
  mul s1,t6,t0
  mul a2,t0,t1
  mul a3,t2,s0
  mul a4,s1,a0
  mul a5,a1,a2
  mul a6,a3,a4
  mul a7,a5,t6
  mul s2,t3,s2
  mul s3,s3,s4
  mul s4,s5,s6
  mul s5,s7,s8
  mul s6,s9,s10
  mul s7,s11,t3
  mul s8,t4,t5
  mul s9,t6,t0
  mul t3,t0,t1
  mul t4,t2,s0
  mul t5,s1,a0
  mul t6,a1,a2
  mul t0,s7,s8
  mul t1,s9,s10
  mul t2,s11,t3
  mul s0,t4,t5
  mul s1,t6,t0
  mul a2,t0,t1
  mul a3,t2,s0
  mul a4,s1,a0
  mul a5,a1,a2
  mul a6,a3,a4
  mul a7,a5,t6
  mul s2,t6,s2
  mul s3,s3,s5
  mul s4,s5,s6
  mul s5,s7,s8
  mul s6,s9,s10
  mul s7,s11,t3
  mul s8,t4,t5
  mul s9,t6,t0
  mul t3,t0,t1
  mul t4,t2,s0
  mul t5,s1,a0
  mul t6,a1,a2
  mul t0,s7,s8
  mul t1,s9,s10
  mul t2,s11,t3
  mul s0,t4,t5
  mul s1,t6,t0
  mul a2,t0,t1
  mul a3,t2,s0
  mul a4,s1,a0
  mul a5,a1,a2
  mul a6,a3,a4
  mul a5,a5,t6
  mul s2,a7,s2
  mul s3,s3,s4
  mul s4,s5,s6
  mul s5,s7,s8
  mul s6,s9,s10
  mul s7,s11,t3
  mul s8,t4,t5
  mul s9,t6,t0
  mul t3,t0,t1
  mul t4,t2,s0
  mul t5,s1,a0
  mul t6,a1,a2
  mul t0,s7,s8
  mul t1,s9,s10
  mul t2,s11,t3
  mul s0,t4,t5
  mul s1,t6,t0
  mul a2,t0,t1
  mul a3,t2,s0
  mul a4,s1,a0
  mul a5,a1,a2
  mul a6,a3,a4
  mul a7,a5,t6
  mul s2,t6,s2
  mul s3,s3,s4
  mul s4,s5,s6
  mul s5,s7,s8
  mul s6,s9,s10
  mul s7,s11,t3
  mul s8,t4,t5
  mul s9,t6,t0
  mul t3,t0,t1
  mul t4,t2,s0
  mul t5,s1,a0
  mul t6,a1,a2
  bsg_asm_saif_end

pass:
  bsg_asm_finish(IO_X_INDEX, 0)

pass_loop:
  beq x0, x0, pass_loop

fail:
  bsg_asm_fail(IO_X_INDEX, 0)

fail_loop:
  beq x0, x0, fail_loop
