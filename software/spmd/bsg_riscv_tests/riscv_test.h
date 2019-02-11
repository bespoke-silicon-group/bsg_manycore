#include "../../../imports/riscv-tests/env/p/riscv_test.h"
#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#ifndef __riscv_xlen
#define __riscv_xlen 32
#endif


#undef RVTEST_CODE_BEGIN
#undef RVTEST_CODE_END
#undef RVTEST_PASS
#undef RVTEST_FAIL


#define RVTEST_CODE_BEGIN 

// implicit pass
#define RVTEST_CODE_END \
    bsg_asm_finish(IO_X_INDEX, 0)       \
1:                                      \
    j 1b;

#define RVTEST_PASS \
    bsg_asm_finish(IO_X_INDEX, 0)       \
1:                                      \
    j 1b;
//the failed value is the test num
#define RVTEST_FAIL \
    bsg_asm_fail_reg(IO_X_INDEX, TESTNUM)         \
1:                                      \
    j 1b;
