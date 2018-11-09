#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// TODO: make this 4KB when hw supports
// the full range
#define MAX_BRANCH (0x100)

.text

// branch forward
test_1:
    beqz zero, test_2;
fail_1:
    bsg_asm_fail(0, 0x1);

// (MAX-4) branch forward
test_3:
    beqz zero, test_4;
    j finish;
fail_3:
    bsg_asm_fail(0, 0x3);

// branch backward
test_2:
    beqz zero, test_3;
fail_2:
    bsg_asm_fail(0, 0x2);

.org test_3+MAX_BRANCH-4
// MAX branch backward
test_4:
    nop;
    nop;
    beqz zero, test_3+4;
fail_4:
    bsg_asm_fail(0, 0x4);

// TODO: add code to test MAX+4 when
// hw supports full range

finish:
    bsg_asm_finish(0);
