#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
//CASE 1:branch forward.
    li          x1, 0x0;
    beqz        x1, check1;
fail1:
    bsg_asm_fail(IO_X_INDEX, 0x1)

check2:
    beqz x1, all_finish;
    bsg_asm_fail(IO_X_INDEX, 0x2);

//CASE 2: branch backward
check1:
    beqz x1, check2;
fail2:
    bsg_asm_fail(IO_X_INDEX, 0x2);

all_finish:
    bsg_asm_finish(IO_X_INDEX,0);

loop:
  beq x0, x0, loop 

