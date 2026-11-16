// FP exception flags must be accrued in a cycle in which a CSR instruction
// on a register other than fflags or fcsr is issued.
//
// Each test clears fflags, runs an FP instruction that raises flags, and
// follows it with CSR reads. With no stalls, a read overlaps the flag arrival.
// Then it checks fflags.

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  bsg_asm_init_regfile

  li x1, 0x7f7fffff // FLT_MAX
  li x2, 0x7fc00000 // NaN
  li x3, 0x3f800000 // 1
  li x4, 0x40400000 // 3
  fmv.s.x f1, x1
  fmv.s.x f2, x2
  fmv.s.x f3, x3
  fmv.s.x f4, x4

// fadd.s (overflow, inexact) and frm reads
_test1:
  li x31, 1
  fsflags x0
  fadd.s f5, f1, f1
  .rept 8
  frrm x5
  .endr
  frflags x6
  li x7, 0x5
  bne x6, x7, fail

// flt.s on NaN (invalid) and mstatus reads
_test2:
  li x31, 2
  fsflags x0
  flt.s x5, f2, f3
  .rept 8
  csrr x5, mstatus
  .endr
  frflags x6
  li x7, 0x10
  bne x6, x7, fail

// fdiv.s (inexact) and frm reads; the divider takes longer, so does the run
_test3:
  li x31, 3
  fsflags x0
  fdiv.s f5, f3, f4
  .rept 32
  frrm x5
  .endr
  frflags x6
  li x7, 0x1
  bne x6, x7, fail

// With no stalls, one nop makes the fadd.s and flt.s flags arrive together.
_test4:
  li x31, 4
  fsflags x0
  fadd.s f5, f1, f1
  nop
  flt.s x5, f2, f3
  .rept 8
  frrm x5
  .endr
  frflags x6
  li x7, 0x15
  bne x6, x7, fail

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
// the fail packet carries the number of the failing test
fail:
  bsg_asm_fail_reg(IO_X_INDEX, x31)
fail_loop:
  beq x0, x0, fail_loop
