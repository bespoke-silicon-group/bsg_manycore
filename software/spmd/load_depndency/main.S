#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text

// loop index
li a0, 3;

prog:
    la a1, N;
    li t0, 0xbaba;
    sw t0, 0x0(a1);
    lw a2, N;
    mv a3, a2;
    bsg_asm_print_reg(IO_X_INDEX,a3);
    addi a0, a0, -1;
    bnez a0, prog;

finish:
    fence;
    li t0, 1;
    csrw mtohost, t0;
    bsg_asm_finish(IO_X_INDEX);
    j finish


.data
N: .word 0xabab
