#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define MAX_BRANCH (0x1000)

.text

_code_section_1_start = .
// branch forward
test_1:
    beqz zero, test_2;
fail_1:
    bsg_asm_fail(IO_X_INDEX, 0x1);
    j end_loop
// (MAX-4) branch forward
test_3:
    beqz zero, test_4;
    j finish;
fail_3:
    bsg_asm_fail(IO_X_INDEX, 0x3);
    j end_loop

// branch backward
test_2:
    beqz zero, test_3;
fail_2:
    bsg_asm_fail(IO_X_INDEX, 0x2);
    j end_loop
_code_section_1_end = .

.org test_3+MAX_BRANCH-4
_code_section_2_start = .
// MAX branch backward
test_4:
    nop;
    nop;
    beqz zero, test_3+4;
fail_4:
    bsg_asm_fail(IO_X_INDEX, 0x4);
    j end_loop

finish:
    bsg_asm_finish(IO_X_INDEX, 0);
end_loop:
  j end_loop
_code_section_2_end = .
