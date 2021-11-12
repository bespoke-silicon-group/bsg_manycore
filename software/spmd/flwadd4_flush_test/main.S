// tests flwadd4 flush when branch mispredict or mret occurs


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
  la t2, float_dmem_arr 
  li t3, 4
  mret
  flwadd4 f0, t2, t3 // this should not execute


_start:
  bsg_asm_init_regfile 
  // enable mstatus.MIE
  li t0, 0x8
  csrrw x0, mstatus, t0
  // enable mie.remote
  li t0, 0x10000
  csrrw x0, mie, t0

// initilize float_arr with 1,2...N-1
init_start:
  li t0, 1
  li t1, N+1
  la t2, float_dram_arr
  la t3, float_dmem_arr
init_loop:
  fcvt.s.w f0, t0
  fsw f0, 0(t2)
  fsw f0, 0(t3)
  addi t2, t2, 4
  addi t3, t3, 4
  addi t0, t0, 1
  bne t0, t1, init_loop
 
  fcvt.s.w f0, x0 // clear f0
  
  
test0:
  la t0, float_dmem_arr
  li t1, 4
  beq x0, x0, validate0
  flwadd4 f0, t0, t1 // this should not execute

validate0:
  fcvt.w.s t0, f0
  fcvt.w.s t1, f1
  fcvt.w.s t2, f2
  fcvt.w.s t3, f3
  bne t0, x0, fail

test1:
  // send itself remote interrupt
  li t2, bsg_tile_group_remote_interrupt_ptr(0,0)
  li t3, 1
  sw t3, 0(t2) // send remote interrupt to self.
  nop
  nop
  nop
  nop
  nop


validate1:
  fcvt.w.s t0, f0
  fcvt.w.s t1, f1
  fcvt.w.s t2, f2
  fcvt.w.s t3, f3
  bne t0, x0, fail

/// END of TEST
pass:
  bsg_asm_finish(IO_X_INDEX,0)
pass_loop:
  beq x0, x0, pass_loop 
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  beq x0, x0, fail_loop 
