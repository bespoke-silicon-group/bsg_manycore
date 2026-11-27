// fmul.s must keep the sign of an exact zero product: the result is -0 when
// the operands have different signs. Checked in every rounding mode.

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  bsg_asm_init_regfile

  li x1, 0x00000000 // +0
  li x2, 0x80000000 // -0
  li x3, 0x3f800000 // +1
  li x4, 0xbf800000 // -1
  fmv.s.x f1, x1
  fmv.s.x f2, x2
  fmv.s.x f3, x3
  fmv.s.x f4, x4

// x30 is the rounding mode, 0 (rne) to 4 (rmm); x31 numbers the products
  li x30, 0
next_rm:
  fsrm x30

// +0 * +1 = +0
  li x31, 1
  fmul.s f5, f1, f3
  fmv.x.s x5, f5
  bne x5, x1, fail

// -0 * +1 = -0
  li x31, 2
  fmul.s f5, f2, f3
  fmv.x.s x5, f5
  bne x5, x2, fail

// +1 * -0 = -0
  li x31, 3
  fmul.s f5, f3, f2
  fmv.x.s x5, f5
  bne x5, x2, fail

// -1 * +0 = -0
  li x31, 4
  fmul.s f5, f4, f1
  fmv.x.s x5, f5
  bne x5, x2, fail

// -1 * -0 = +0
  li x31, 5
  fmul.s f5, f4, f2
  fmv.x.s x5, f5
  bne x5, x1, fail

// -0 * +0 = -0
  li x31, 6
  fmul.s f5, f2, f1
  fmv.x.s x5, f5
  bne x5, x2, fail

  addi x30, x30, 1
  li x6, 5
  bne x30, x6, next_rm

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
// the fail packet carries 16 * rounding mode + product number
fail:
  slli x30, x30, 4
  or x31, x31, x30
  bsg_asm_fail_reg(IO_X_INDEX, x31)
fail_loop:
  beq x0, x0, fail_loop
