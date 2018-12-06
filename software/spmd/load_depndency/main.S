#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text

// loop index
li ra, 10;

sum:
    bsg_asm_remote_store(0, 0, 0x1000, 1);
    bsg_asm_remote_store(0, 0, 0x1004, 2);
    bsg_asm_remote_store(0, 0, 0x1008, 3);
    bsg_asm_remote_store(0, 0, 0x100c, 4);
    bsg_asm_remote_store(0, 0, 0x1010, 5);
    bsg_asm_remote_store(0, 0, 0x1014, 6);
    bsg_asm_remote_store(0, 0, 0x1018, 7);
    bsg_asm_remote_store(0, 0, 0x101c, 8);
    bsg_asm_remote_load(a0, 0, 0, 0x1000);
    bsg_asm_remote_load(a1, 0, 0, 0x1004);
    bsg_asm_remote_load(a2, 0, 0, 0x1008);
    bsg_asm_remote_load(a3, 0, 0, 0x100c);
    bsg_asm_remote_load(a4, 0, 0, 0x1010);
    bsg_asm_remote_load(a5, 0, 0, 0x1014);
    bsg_asm_remote_load(a6, 0, 0, 0x1018);
    bsg_asm_remote_load(a7, 0, 0, 0x101c);
    add a1, a0, a1;
    add a2, a1, a2;
    add a3, a2, a3;
    add a4, a3, a4;
    add a5, a4, a5;
    add a6, a5, a6;
    add a7, a6, a7;
    bsg_asm_print_reg(IO_X_INDEX,a7);
    addi ra, ra, -1;
    bnez ra, sum;

finish:
    fence;
    li t0, 1;
    csrw mtohost, t0;
    bsg_asm_finish(IO_X_INDEX);
    j finish


.data
N: .word 0xabab
