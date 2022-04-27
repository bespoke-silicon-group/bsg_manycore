#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

//.data
//  float_dmem_arr: .space 64 // array of 16 floats
//.section .dram, "aw"
//  float_dram_arr: .space 64

.section .dram, "aw"
dram_word: .word -1

.text
        bsg_asm_init_regfile

// test1
test1:
        la       x1, dram_word
        addi     x2, x0, -1
        // prime
        lw       x3,   0(x1)
        lw       x4,  64(x1)
        bne      x2, x3, fail
        // do many remote loads
        // first block
        lw       x4,   0(x1)
        lw       x5,   4(x1)
        lw       x6,   8(x1)
        lw       x7,  12(x1)
        lw       x8,  16(x1)
        lw       x9,  20(x1)
        lw      x10,  24(x1)
        lw      x11,  28(x1)
        lw      x12,  32(x1)
        lw      x13,  36(x1)
        lw      x14,  40(x1)
        lw      x15,  44(x1)
        lw      x16,  48(x1)
        lw      x17,  52(x1)
        lw      x18,  56(x1)
        lw      x19,  60(x1)
        // second block
        lw      x20,  64(x1)
        lw      x21,  68(x1)
        lw      x22,  72(x1)
        lw      x23,  76(x1)
        lw      x24,  80(x1)
        lw      x25,  84(x1)
        lw      x26,  88(x1)
        lw      x27,  92(x1)
        lw      x28,  96(x1)
        lw      x29, 100(x1)
        lw      x30, 104(x1)
        lw      x31, 108(x1)
        div     x1, x3, x2
        // lw      x4, 112(x1)
        // lw      x4, 116(x1)
        // lw      x4, 120(x1)
        // lw      x4, 124(x1)
        bne     x3, x2, fail
pass:
        bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
        beq     x0, x0, pass_loop
fail:
        bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
        beq     x0, x0, fail_loop
