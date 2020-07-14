#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

li x10, 2

1:
  li x1, 5
  li x2, 5
  la x3, 2f
  la x4, 3f
  mul x1, x1, x2
  jalr x5, x3, 0

2:
  jalr x6, x4, 0 // back to back jalrs during md stall

3:
  la x7, 2b
  la x8, 3b
  bne x5, x7, fail
  bne x6, x8, fail
  addi x10, x10, -1
  bne x0, x10, 1b

pass:
  bsg_asm_finish(IO_X_INDEX, 0)

fail:
  bsg_asm_fail(IO_X_INDEX, -1)
