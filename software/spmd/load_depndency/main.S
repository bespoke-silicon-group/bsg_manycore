#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text

// loop index
// iterate to run without cache misses
li ra, 2;

sum:
    // Store data in some locations
    bsg_asm_remote_store(0, 0, 0x1000, 1);
    bsg_asm_remote_store(0, 0, 0x1004, 2);
    bsg_asm_remote_store(0, 0, 0x1008, 3);
    bsg_asm_remote_store(0, 0, 0x100c, 4);
    bsg_asm_remote_store(0, 0, 0x1010, 5);
    bsg_asm_remote_store(0, 0, 0x1014, 6);
    bsg_asm_remote_store(0, 0, 0x1018, 7);
    bsg_asm_remote_store(0, 0, 0x101c, 8);
    fence;

    // Single cycle remote loads
    // nops to test zero delay remote loads
    bsg_asm_remote_load(a0, 0, 0, 0x1000);
    bsg_asm_remote_load(a1, 0, 0, 0x1004);
    bsg_asm_remote_load(a2, 0, 0, 0x1008);
    bsg_asm_remote_load(a3, 0, 0, 0x100c);
    nop;
    nop;
    nop;
    nop;
    nop;
    nop;
    nop;
    nop;
    nop;
    nop;
    add a1, a0, a1;
    add a2, a1, a2;
    add a3, a2, a3;

    // Load write-back during stalls
    // A dummy multiply is used to create a stall
    bsg_asm_remote_load(a4, 0, 0, 0x1010);
    nop; // nops to let load pass through the pipeline before stall
    nop;
    mul t0, t0, t0;
    add a4, a3, a4;

    // Dependency test
    bsg_asm_remote_load(a5, 0, 0, 0x1014);
    bsg_asm_remote_load(a6, 0, 0, 0x1018);
    bsg_asm_remote_load(a7, 0, 0, 0x101c);
    add a5, a4, a5;
    add a6, a5, a6;
    add a7, a6, a7;

    // print the result
    bsg_asm_print_reg(IO_X_INDEX,a7);

    addi ra, ra, -1;
    bnez ra, sum;
// sum

finish:
    fence;
    li t0, 1;
    csrw mtohost, t0;
    bsg_asm_finish(IO_X_INDEX);
    j finish
