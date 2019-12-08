#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  bsg_asm_finish(IO_X_INDEX, 0)
loop:
  beq x0, x0, loop
