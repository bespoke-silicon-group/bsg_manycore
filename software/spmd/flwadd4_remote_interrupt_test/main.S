// tests remote interrupt while flwadd4 being expanded.


#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

#define N 16

.section .dram, "aw"
  float_dram_arr: .space (N*4)
.data // DMEM
  buffer: .space 8 // for spilling registers
  float_dmem_arr: .space (N*4)


.text

_remote_interrupt:
  j _remote_interrupt_handler
_trace_interrupt:
  j fail
_remote_interrupt_handler:
  fence
  // save two registers (t0, t1) to the reserved spot in DMEM
  sw t0, 0(x0)
  sw t1, 4(x0)
  // clear mip.remote
  li t0, 0x10000
  csrrc x0, mip, t0
  // restore saved registers
  lw t0, 0(x0)
  lw t1, 4(x0)
  mret


_start:
  bsg_asm_init_regfile 
  // enable mstatus.MIE
  li t0, 0x8
  csrrw x0, mstatus, t0
  // enable mie.remote
  li t0, 0x10000
  csrrw x0, mie, t0

init_start:
  li t0, 0
  li t1, N
  la t2, float_dram_arr
  la t3, float_dmem_arr

// initilize float_arr with 0,1,2...N-1
init_loop:
  fcvt.s.w f0, t0
  fsw f0, 0(t2)
  fsw f0, 0(t3)
  addi t2, t2, 4
  addi t3, t3, 4
  addi t0, t0, 1
  bne t0, t1, init_loop
 

  
  
test0:
  la t0, float_dram_arr
  li t1, 4
  li t2, bsg_tile_group_remote_interrupt_ptr(0,0)
  li t3, 1
  flwadd4 f0, t0, t1
  sw t3, 0(t2) // send remote interrupt to self.
  flwadd4 f4, t0, t1
  sw t3, 0(t2) // send remote interrupt to self.
  flwadd4 f8, t0, t1
  flwadd4 f12, t0, t1

validate0:
  fcvt.w.s t0, f0
  fcvt.w.s t1, f1
  fcvt.w.s t2, f2
  fcvt.w.s t3, f3
  li s0, 0
  li s1, 1
  li s2, 2
  li s3, 3
  bne t0, s0, fail
  bne t1, s1, fail
  bne t2, s2, fail
  bne t3, s3, fail

  fcvt.w.s t0, f4
  fcvt.w.s t1, f5
  fcvt.w.s t2, f6
  fcvt.w.s t3, f7
  li s0, 4
  li s1, 5
  li s2, 6
  li s3, 7
  bne t0, s0, fail
  bne t1, s1, fail
  bne t2, s2, fail
  bne t3, s3, fail

  fcvt.w.s t0, f8
  fcvt.w.s t1, f9
  fcvt.w.s t2, f10
  fcvt.w.s t3, f11
  li s0, 8
  li s1, 9
  li s2, 10
  li s3, 11
  bne t0, s0, fail
  bne t1, s1, fail
  bne t2, s2, fail
  bne t3, s3, fail

  fcvt.w.s t0, f12
  fcvt.w.s t1, f13
  fcvt.w.s t2, f14
  fcvt.w.s t3, f15
  li s0, 12
  li s1, 13
  li s2, 14
  li s3, 15
  bne t0, s0, fail
  bne t1, s1, fail
  bne t2, s2, fail
  bne t3, s3, fail


test1:
  la t0, float_dmem_arr
  li t1, 4
  li t2, bsg_tile_group_remote_interrupt_ptr(0,0)
  li t3, 1
  flwadd4 f16, t0, t1
  sw t3, 0(t2) // send remote interrupt to self.
  flwadd4 f20, t0, t1
  sw t3, 0(t2) // send remote interrupt to self.
  flwadd4 f24, t0, t1
  flwadd4 f28, t0, t1


validate1:
  fcvt.w.s t0, f16 
  fcvt.w.s t1, f17
  fcvt.w.s t2, f18
  fcvt.w.s t3, f19 
  li s0, 0
  li s1, 1
  li s2, 2
  li s3, 3
  bne t0, s0, fail
  bne t1, s1, fail
  bne t2, s2, fail
  bne t3, s3, fail





pass:
  bsg_asm_finish(IO_X_INDEX,0)
pass_loop:
  beq x0, x0, pass_loop 
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop 
