#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

//.data
//  float_dmem_arr: .space 64 // array of 16 floats
//.section .dram, "aw"
//  float_dram_arr: .space 64

.text
  bsg_asm_init_regfile

// test1
test1:
  beq x0, x0, pass  // this fwd branch will be predicted "not taken". 
  j here0

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop

.org (4096)
here0:
  bne t2, a0, fail
here0_loop:
  beq x0, x0, here0_loop
