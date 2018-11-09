#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// TODO: make this 1MB after hw supports
// the complete range
#define MAX_JUMP (0x100)

// jump and save: executes a jump to the label 
// and saves the address following the jump in x2
.macro js label
auipc x2, 0;
addi x2, x2, 12;
jal x1, \label;
.endm

.text
// jump forward
test_1:
    js test_2;
fail_1:
    bsg_asm_fail(0, 0x1);

// (MAX-4) jump forward
test_3:
    bne x1, x2, fail_2;
    js 3f;
    nop;
    bne x1, x2, fail_3;
    js test_4;
fail_3:
    bsg_asm_fail(0, 0x3);

// jump backward
test_2:
    bne x1,x2,fail_1;
    js test_3;
fail_2:
    bsg_asm_fail(0, 0x2);

// MAX jump forward
// The offset should actually overflow and result
// in MAX jump backward. But since the current hw doesn't
// support 1MB jumps, overflow is not observed.
// TODO: modify this after hardware supports 1MB jumps
test_4:
    bne x1,x2,fail_3;
    js 4f;
    nop;
    bne x1,x2,fail_4;
    js finish;
fail_4:
    bsg_asm_fail(0, 0x4);

// MAX jump backward
.org test_3+MAX_JUMP+8
3:
    bne x1, x2, fail_3;
    js test_3+20;
    bsg_asm_fail(0, 0x3);

// (MAX+4) jump backward
// TODO: modify this after hardware supports 1MB jumps
.org test_4+MAX_JUMP+12
4:
    bne x1,x2,fail_4;
    js test_4+20;
    bsg_asm_fail(0, 0x4);

finish:
    bsg_asm_finish(0);
