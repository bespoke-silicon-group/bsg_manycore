#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text

// Loop index
// Iterate to run without cache misses
li ra, 10;

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
    bsg_asm_local_store(0x1020, 9);
    bsg_asm_local_store(0x1024, 10);
    bsg_asm_local_store(0x1028, 11);
    bsg_asm_local_store(0x102c, 12);
    bsg_asm_local_store(0x1030, 13);
    bsg_asm_local_store(0x1034, 14);
    bsg_asm_local_store(0x1038, 15);
    fence;

test_1:
    // Single cycle remote loads
    // nops to test zero delay remote loads
    bsg_asm_remote_load(s0, 0, 0, 0x1000); // 1
    bsg_asm_remote_load(s1, 0, 0, 0x1004); // 2
    bsg_asm_remote_load(s2, 0, 0, 0x1008); // 3
    bsg_asm_remote_load(s3, 0, 0, 0x100c); // 4
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
    add s1, s0, s1;
    add s2, s1, s2;
    add s0, s2, s3;
    bi(beq, s0, 10, test_2);
    bsg_asm_fail(IO_X_INDEX, 1);

test_2:
    // Load write-back during stalls
    // A dummy multiply is used to create a stall
    bsg_asm_remote_load(s1, 0, 0, 0x1010); // 5
    nop; // nops to let load pass through the pipeline before stall
    nop;
    mul t0, t0, t0;
    add s0, s1, s0;
    bi(beq, s0, 15, test_3);
    bsg_asm_fail(IO_X_INDEX, 2);

test_3:
    // Dependency test
    bsg_asm_remote_load(s1, 0, 0, 0x1014); // 6
    bsg_asm_remote_load(s2, 0, 0, 0x1018); // 7
    add s1, s0, s1;
    add s0, s1, s2;
    bi(beq, s0, 28, test_4);
    bsg_asm_fail(IO_X_INDEX, 3);

test_4:
    // Contention between remote and local loads
    li a0, 0x1028;
    li a1, 0x102c;
    li a2, 0x1030;
    li a3, 0x1034;
    li a4, 0x1038;
    bsg_asm_remote_load(s1, 0, 0, 0x101c); // 8
    bsg_asm_remote_load(s2, 0, 0, 0x1020); // 9
    bsg_asm_remote_load(s3, 0, 0, 0x1024); // 10
    lw s4, 0x0(a0); // 11
    lw s5, 0x0(a1); // 12
    lw s6, 0x0(a2); // 13
    lw s7, 0x0(a3); // 14
    lw s8, 0x0(a4); // 15
    lw s8, 0x0(a4); // 15
    lw s8, 0x0(a4); // 15
    lw s8, 0x0(a4); // 15
    lw s8, 0x0(a4); // 15
    lw s8, 0x0(a4); // 15
    lw s8, 0x0(a4); // 15
    lw s8, 0x0(a4); // 15
    add s1, s0, s1;
    add s2, s1, s2;
    add s3, s2, s3;
    add s4, s3, s4;
    add s5, s4, s5;
    add s6, s5, s6;
    add s7, s6, s7;
    add s0, s7, s8;

    // print the result
    bsg_asm_print_reg(IO_X_INDEX,s0);
    
    // check result = sum of 15 natural numbers
    .equ res, (15*16/2)
    li t0, res;
    beq s0, t0, done;
    bsg_asm_fail(IO_X_INDEX, 4);

done:
    addi ra, ra, -1;
    bnez ra, sum;
// sum

bsg_asm_finish(IO_X_INDEX, 0);
