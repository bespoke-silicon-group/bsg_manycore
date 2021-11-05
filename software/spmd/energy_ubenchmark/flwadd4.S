#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
  // initialize
  li t0, 0
  li t1, 4096
  li t2, 0xbf83d70a // = -1.03
  fmv.s.x f0, t2
  li s0, 0
  li s1, 4  // stride

init_loop:
  flw f0, 0(t0)
  fmul.s f0, f0, f0
  addi t0, t0, 4
  bne t0, t1, init_loop

  nop
  nop
  nop
  bsg_asm_saif_start

flwadd4 f0, s0, s1
flwadd4 f4, s0, s1
flwadd4 f8, s0, s1
flwadd4 f12, s0, s1
flwadd4 f16, s0, s1
flwadd4 f20, s0, s1
flwadd4 f24, s0, s1
flwadd4 f28, s0, s1
flwadd4 f0, s0, s1
flwadd4 f4, s0, s1
flwadd4 f8, s0, s1
flwadd4 f12, s0, s1
flwadd4 f16, s0, s1
flwadd4 f20, s0, s1
flwadd4 f24, s0, s1
flwadd4 f28, s0, s1
flwadd4 f0, s0, s1
flwadd4 f4, s0, s1
flwadd4 f8, s0, s1
flwadd4 f12, s0, s1
flwadd4 f16, s0, s1
flwadd4 f20, s0, s1
flwadd4 f24, s0, s1
flwadd4 f28, s0, s1
flwadd4 f0, s0, s1


  bsg_asm_saif_end


pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop
