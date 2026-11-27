// When the rounded integer result does not fit, fcvt.w.s and fcvt.wu.s
// return the clipped result and raise invalid (0x10), not overflow (0x04).
// A valid conversion raises nothing, or inexact (0x01) when it rounds.

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// Convert val with inst, then check the result and fflags.
// The fail packet carries the test number.
#define TEST_FCVT(n, inst, val, result, flags) \
  li x31, n; \
  li x1, val; \
  fmv.s.x f1, x1; \
  fsflags x0; \
  inst x5, f1; \
  frflags x6; \
  li x7, result; \
  bne x5, x7, fail; \
  li x7, flags; \
  bne x6, x7, fail;

.text
  fsrm x0 // These cases use round-to-nearest, ties-to-even.
  bsg_asm_init_regfile

  TEST_FCVT( 1, fcvt.w.s,  0x4f000000, 0x7fffffff, 0x10) // 2^31
  TEST_FCVT( 2, fcvt.w.s,  0xcf800000, 0x80000000, 0x10) // -2^32
  TEST_FCVT( 3, fcvt.w.s,  0x7f800000, 0x7fffffff, 0x10) // +inf
  TEST_FCVT( 4, fcvt.w.s,  0xcf000000, 0x80000000, 0x00) // -2^31 fits
  TEST_FCVT( 5, fcvt.w.s,  0x3fc00000, 0x00000002, 0x01) // 1.5 rounds to 2

  TEST_FCVT( 6, fcvt.wu.s, 0xbf800000, 0x00000000, 0x10) // -1
  TEST_FCVT( 7, fcvt.wu.s, 0x4f800000, 0xffffffff, 0x10) // 2^32
  TEST_FCVT( 8, fcvt.wu.s, 0x7fc00000, 0xffffffff, 0x10) // NaN
  TEST_FCVT( 9, fcvt.wu.s, 0x4f000000, 0x80000000, 0x00) // 2^31 fits
  TEST_FCVT(10, fcvt.wu.s, 0xbf000000, 0x00000000, 0x01) // -0.5 rounds to 0

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail_reg(IO_X_INDEX, x31)
fail_loop:
  beq x0, x0, fail_loop
