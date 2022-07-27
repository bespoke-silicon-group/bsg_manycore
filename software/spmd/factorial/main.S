#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// Calculate factorial of N
#define N 10

.text

li gp, 1; // repeat the program to reduce cache miss effect

fact:
    li ra, N;

unrolled_loop:
    addi t0, ra, -8;
    blt t0, zero, tail_loop;
    bsg_asm_remote_store_reg(0, 0, 0x1000, ra);
    addi ra, ra, -1;
    bsg_asm_remote_store_reg(0, 0, 0x1004, ra);
    addi ra, ra, -1;
    bsg_asm_remote_store_reg(0, 0, 0x1008, ra);
    addi ra, ra, -1;
    bsg_asm_remote_store_reg(0, 0, 0x100c, ra);
    addi ra, ra, -1;
    bsg_asm_remote_store_reg(0, 0, 0x1010, ra);
    addi ra, ra, -1;
    bsg_asm_remote_store_reg(0, 0, 0x1014, ra);
    addi ra, ra, -1;
    bsg_asm_remote_store_reg(0, 0, 0x1018, ra);
    addi ra, ra, -1;
    bsg_asm_remote_store_reg(0, 0, 0x101c, ra);
    addi ra, ra, -1;
    bsg_asm_remote_load(a0, 0, 0, 0x1000);
    bsg_asm_remote_load(a1, 0, 0, 0x1004);
    bsg_asm_remote_load(a2, 0, 0, 0x1008);
    bsg_asm_remote_load(a3, 0, 0, 0x100c);
    bsg_asm_remote_load(a4, 0, 0, 0x1010);
    bsg_asm_remote_load(a5, 0, 0, 0x1014);
    bsg_asm_remote_load(a6, 0, 0, 0x1018);
    bsg_asm_remote_load(a7, 0, 0, 0x101c);
    mul a1, a0, a1;
    mul a2, a1, a2;
    mul a3, a2, a3;
    mul a4, a3, a4;
    mul a5, a4, a5;
    mul a6, a5, a6;
    mul a7, a6, a7;
    j unrolled_loop;

tail_loop:
    bsg_asm_remote_store_reg(0, 0, 0x1000, ra);
    bsg_asm_remote_load(a0, 0, 0, 0x1000);
    mul a7, a7, a0;
    addi ra, ra, -1;
    bnez ra, tail_loop;
    
    addi gp, gp, -1;
    bnez gp, fact;

bsg_asm_print_reg(IO_X_INDEX,a7);

finish:
    fence;
    li t0, 1;
    bsg_asm_finish(IO_X_INDEX, 0);
    //j finish

