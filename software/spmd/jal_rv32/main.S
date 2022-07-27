#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define MAX_JUMP (0x100000)

// jump and save: executes a jump to the label 
// and saves the address following the jump in x2
.macro js label
auipc x2, 0;
addi x2, x2, 12;
jal x1, \label;
.endm

.text

_code_section_1_start = .
// jump forward
test_1:
    js test_2;
fail_1:
    bsg_asm_fail(IO_X_INDEX, 0x1);

// (MAX-4) jump forward
test_3:
    bne x1, x2, fail_2;
    js 3f;
    nop;
    bne x1, x2, fail_3;
    la t0, finish;
    jr t0;
fail_3:
    bsg_asm_fail(IO_X_INDEX, 0x3);

// jump backward
test_2:
    bne x1,x2,fail_1;
    js test_3;
fail_2:
    bsg_asm_fail(IO_X_INDEX, 0x2);
_code_section_1_end = .


// MAX jump backward
.org test_3+MAX_JUMP+8
_code_section_2_start = .
3:
    bne x1, x2, fail_3;
    js test_3+24;
    bsg_asm_fail(IO_X_INDEX, 0x3);

finish:
    fence;
    li t0, 1;
    //csrw mtohost, t0;
    bsg_asm_finish(IO_X_INDEX, 0);
    //j finish
_code_section_2_end = .
