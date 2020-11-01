#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text

start:
  addi t1, x0, 1
  addi t2, x0, 1
  add t3, x0, x0
  add t3, t3, t1
  add t3, t3, t2
  add t3, t3, t1
  add t3, t3, t2
  add t3, t3, t1
  add t3, t3, t2
  add t3, t3, t1
  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3
  add t3, t3, t1
  add x0, t3, t3
  add x0, t3, t3
  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3
  add t3, t3, t1
  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3
  add t3, t3, t2
  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3
  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3
  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3

  add t3, t3, t2
  add x0, t3, t3

  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3

  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3

  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3

  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3
  add x0, t3, t3

  add t3, t3, t2
  add t3, t3, t2
  add x0, t3, t3

  add t3, t3, t2
  add t3, t3, t2
  add x0, t3, t3
  add x0, t3, t3

  add t3, t3, x0
  add x0, t3, t3
  add t3, t3, x0
  add t3, x0, t3
  add t3, t3, x0
  add x0, t3, t3
  add t3, x0, t3
  add t3, t3, x0
  add t3, x0, t3
  add x0, t3, t3
  add t3, t3, x0
  add t3, t3, x0
  add t3, x0, t3
  add x0, t3, t3
  add t3, t3, x0
  add t3, x0, t3
  add t3, x0, t3
  add t3, t3, x0
  add x0, t3, t3
  add x0, t3, t3
  add t3, t3, x0
  add t3, x0, t3
  add t3, t3, x0
  add t3, x0, t3
  add t3, x0, t3
  add t3, t3, x0
  add x0, t3, t3
  add t3, x0, t3
  add t3, x0, t3
  add t3, t3, x0
  add x0, t3, t3
  add t3, x0, t3
  add t3, x0, t3
  add t3, t3, x0
  add x0, t3, t3
  add t3, x0, t3
  add t3, x0, t3
  add t3, t3, x0
  add x0, t3, t3
  add x0, t3, t3
  add t3, t3, x0
  add t3, x0, t3
  add t3, x0, t3
  add t3, x0, t3
 
  add t3, t3, t1 
  add t3, x0, t3
  add t3, x0, t3
  add t3, t3, x0
  add x0, t3, t3
  add t3, x0, t3
  add t3, x0, t3
  add t3, t3, x0
  add x0, t3, t3
  add x0, t3, t3
  add t3, t3, x0
  add t3, t3, t1 
  add t3, x0, t3
  add t3, x0, t3
  add t3, t3, x0
  add x0, t3, t3
  add x0, t3, t3
  add t3, t3, x0
  add t3, t3, t1 
  add t3, x0, t3
  add t3, x0, t3
  add t3, t3, x0

  addi t4, x0, 28
  bne t3, t4, fail

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop

fail:
  bsg_asm_fail(IO_X_INDEX, -1)
fail_loop:
  j fail_loop
