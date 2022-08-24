#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"
#define N 1024

.section .dram, "aw"
  dram_arr: .space 16   // allocate 4 words in DRAM

.text
bsg_asm_init_regfile

// setup: an array of alternating int and float
// dram_arr[0] = int = 1
// dram_arr[1] = float = 1.0f
// dram_arr[2] = int = 2
// dram_arr[3] = float = 2.0f
la t0, dram_arr
li t1, 1
sw t1, 0(t0)
li t1, 2
sw t1, 8(t0)

li t1, 0x3f800000
sw t1, 4(t0)
li t1, 0x40000000
sw t1, 12(t0)

fence

// load those values

lw t1, 0(t0)
flw ft2, 4(t0)
lw t3, 8(t0)
flw ft4, 12(t0)


// validate 1 + 2 = 3
add s0, t1, t3
li t0, 3
bne t0, s0, fail

// validate 1.0f + 2.0f = 3.0f
fadd.s ft0, ft2, ft4
fcvt.w.s s1, ft0
li s2, 3
bne s2, s1, fail



pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  j fail_loop
