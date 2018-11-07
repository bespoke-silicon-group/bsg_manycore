#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
    la x2, fail;
    jal x1, check;

fail:
    bsg_asm_fail(0)

check:
    bsg_asm_print_reg(0,x1)
    bsg_asm_print_reg(0,x2)
    bne x1, x2, fail;
    bsg_asm_finish(0)
