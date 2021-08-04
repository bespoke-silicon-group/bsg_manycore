#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl bsg_set_tile_x_y
.globl __bsg_id

.text
_start:
  bsg_asm_init_regfile

  // everyone calculates __bsg_id.
  call bsg_set_tile_x_y

  // everyone print_int __bsg_id.
  la t0, __bsg_id  
  lw t0, 0(t0)
  li t1, bsg_asm_global_ptr(IO_X_INDEX, IO_Y_INDEX, 0xEAE0);
  sw t0, 0(t1)

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop
