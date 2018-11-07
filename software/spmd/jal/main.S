#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
//CASE 1:jump forward.
    la x2, fail1;
    jal x1, check1;
fail1:
    bsg_asm_fail(0, 0x1)

check2:
    bne x1, x2, fail2;
    jal x0, all_finish;

check1:
//    bsg_asm_print_reg(0,x1)
//    bsg_asm_print_reg(0,x2)
    bne x1, x2, fail1;
    
//CASE 2: jump backward
    la  x2,  fail2;
    jal x1, check2;
fail2:
    bsg_asm_fail(0, 0x2);

all_finish:
    bsg_asm_finish(0);



