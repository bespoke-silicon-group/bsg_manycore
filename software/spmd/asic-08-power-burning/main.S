// toggle every bit in DMEM.

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.globl bsg_set_tiles_x_y
.globl __bsg_x
.globl __bsg_y
.globl __bsg_id

.data
  remote_dmem_ptr: .space 16

// initialize
.text
_start:
  bsg_asm_init_regfile

  // everyone calculates __bsg_id
  call bsg_set_tile_x_y 


  // dram pointer
  li s0, 0x80000000
  la t0, __bsg_id
  lw t0, 0(t0)
  slli t0, t0, 5
  add s0, s0, t0  // DRAM base addr
  li s1, 0x1000   // DRAM incr

  // Remote DMEM (use tornado pattern)
  li s2, 0x20000000
  // xcord
  la t0, __bsg_x
  lw t0, 0(t0)
  addi t0, t0, 8
  andi t0, t0, 0xf
  slli t0, t0, 18
  add s2, s2, t0
  // ycord
  la t0, __bsg_y
  lw t0, 0(t0)
  addi t0, t0, 4
  addi t0, t0, 0x7
  slli t0, t0, 24
  add s2, s2, t0
  // dmem addr
  la t0, remote_dmem_ptr
  add s2, s2, t0
  
  // idiv
  li s3, 1000000
  li s4, 3

  // fdiv
  fcvt.s.w f0, s3
  fcvt.s.w f1, s4

  // fma
  li t0, 999999
  fcvt.s.w f3, t0
  li t0, 888
  fcvt.s.w f4, t0
  li t0, -222
  fcvt.s.w f5, t0
  li t0, -1111111
  fcvt.s.w f6, t0
  li t0, -999999
  fcvt.s.w f7, t0
  li t0, -666666
  fcvt.s.w f8, t0
  li t0, -1
  fcvt.s.w f9, t0
  li t0, 111
  fcvt.s.w f10, t0

  // iterate times
  li t0, 100

// Loop body
loop:
  // idiv
  div s5, s3, s4 
  // fdiv
  fdiv.s f2, f0, f1

  // remote store to vcache;
#ifdef USE_DRAM
  sw s0, 0(s0)
#endif

  // remote store to DMEM;
  sw s2, 0(s2)

  // fma
  fmadd.s  f12, f3, f4, f5
  fmsub.s  f13, f6, f7, f8
  fnmadd.s f14, f9, f10, f3
  fnmsub.s f15, f4, f5, f6
  sw s2, 0(s2)
  fmadd.s  f12, f3, f4, f5
  fmsub.s  f13, f6, f7, f8
  fnmadd.s f14, f9, f10, f3
  fnmsub.s f15, f4, f5, f6
  sw s2, 0(s2)
  fmadd.s  f12, f3, f4, f5
  fmsub.s  f13, f6, f7, f8
  fnmadd.s f14, f9, f10, f3
  fnmsub.s f15, f4, f5, f6
  sw s2, 0(s2)
  fmadd.s  f12, f3, f4, f5
  fmsub.s  f13, f6, f7, f8
  fnmadd.s f14, f9, f10, f3
  fnmsub.s f15, f4, f5, f6
  sw s2, 0(s2)
  fmadd.s  f12, f3, f4, f5
  fmsub.s  f13, f6, f7, f8
  fnmadd.s f14, f9, f10, f3
  fnmsub.s f15, f4, f5, f6
  sw s2, 0(s2)
  fmadd.s  f12, f3, f4, f5
  fmsub.s  f13, f6, f7, f8
  fnmadd.s f14, f9, f10, f3
  fnmsub.s f15, f4, f5, f6
  sw s2, 0(s2)
  fmadd.s  f12, f3, f4, f5
  fmsub.s  f13, f6, f7, f8
  fnmadd.s f14, f9, f10, f3
  fnmsub.s f15, f4, f5, f6

  // decrement iter count;
  addi t0, t0, -1
  bne t0, x0, loop




pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop

fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  j fail_loop
  nop
  nop
