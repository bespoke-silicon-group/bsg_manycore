// icache_ring_test: RING loops, each 4096 bytes apart in program space, run
// in a ring (loop k jumps to loop k+1, the last one back to loop 0). Every
// loop's blocks map to the same icache sets for any geometry up to 4 KB per
// way, so a set sees RING different blocks. With RING = ways + 1 (the default,
// from BSG_MACHINE_ICACHE_WAYS) every visit misses and the replacement logic
// picks a victim with every way full. The loops add up dram_arr; a wrong
// victim or a corrupted way changes the sum or the control flow.

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#ifndef RING
#define RING 2
#endif
#if RING < 1 || RING > 9
#error "icache_ring_test supports RING from 1 to 9"
#endif

#define N 360
#define ANSWER (N*(N-1)/2)

.section .dram, "aw"
dram_arr:
  .set i, 0
  .rept N
  .word i
  .set i, i+1
  .endr

.text
  bsg_asm_init_regfile

test_init:
  li s0, N
  la s1, dram_arr
  li s2, 0 // sum
  j loop0

.org (4096*1)
loop0:
  lw t0, 0(s1)
  add s2, s2, t0
  addi s1, s1, 4
  addi s0, s0, -1
  beq x0, s0, check_result
#if RING > 1
  j loop1
#else
  j loop0
#endif

#if RING > 1
.org (4096*2)
loop1:
  lw t0, 0(s1)
  add s2, s2, t0
  addi s1, s1, 4
  addi s0, s0, -1
  beq x0, s0, check_result
#if RING > 2
  j loop2
#else
  j loop0
#endif
#endif

#if RING > 2
.org (4096*3)
loop2:
  lw t0, 0(s1)
  add s2, s2, t0
  addi s1, s1, 4
  addi s0, s0, -1
  beq x0, s0, check_result
#if RING > 3
  j loop3
#else
  j loop0
#endif
#endif

#if RING > 3
.org (4096*4)
loop3:
  lw t0, 0(s1)
  add s2, s2, t0
  addi s1, s1, 4
  addi s0, s0, -1
  beq x0, s0, check_result
#if RING > 4
  j loop4
#else
  j loop0
#endif
#endif

#if RING > 4
.org (4096*5)
loop4:
  lw t0, 0(s1)
  add s2, s2, t0
  addi s1, s1, 4
  addi s0, s0, -1
  beq x0, s0, check_result
#if RING > 5
  j loop5
#else
  j loop0
#endif
#endif

#if RING > 5
.org (4096*6)
loop5:
  lw t0, 0(s1)
  add s2, s2, t0
  addi s1, s1, 4
  addi s0, s0, -1
  beq x0, s0, check_result
#if RING > 6
  j loop6
#else
  j loop0
#endif
#endif

#if RING > 6
.org (4096*7)
loop6:
  lw t0, 0(s1)
  add s2, s2, t0
  addi s1, s1, 4
  addi s0, s0, -1
  beq x0, s0, check_result
#if RING > 7
  j loop7
#else
  j loop0
#endif
#endif

#if RING > 7
.org (4096*8)
loop7:
  lw t0, 0(s1)
  add s2, s2, t0
  addi s1, s1, 4
  addi s0, s0, -1
  beq x0, s0, check_result
#if RING > 8
  j loop8
#else
  j loop0
#endif
#endif

#if RING > 8
.org (4096*9)
loop8:
  lw t0, 0(s1)
  add s2, s2, t0
  addi s1, s1, 4
  addi s0, s0, -1
  beq x0, s0, check_result
  j loop0
#endif

.org (4096*10)
check_result:
  li t0, ANSWER
  bne t0, s2, fail

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
fail:
  bsg_asm_print_reg(IO_X_INDEX, s2)
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  j fail_loop
