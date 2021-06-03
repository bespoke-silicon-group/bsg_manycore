// icache miss test


#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

_start:
  bsg_asm_init_regfile
  j pass

.org 4096
pass:
  bsg_asm_finish(IO_X_INDEX, 0)

pass_loop:
  beq x0, x0, pass_loop

fail:
  bsg_asm_fail(IO_X_INDEX, 0)

fail_loop:
  beq x0, x0, fail_loop
