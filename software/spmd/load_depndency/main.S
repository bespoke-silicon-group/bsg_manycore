#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text

li x5, 10;

prog:
    li x1, 0xbaba;
    sw x1, N, x0;
    lw x2, N;
    mv x3, x2;
    addi x5, x5, -1;
    bnez x5, prog;

finish:
    fence;
    li t0, 1;
    csrw mtohost, t0;
    bsg_asm_finish(IO_X_INDEX);
    j finish

.data

N: .word
