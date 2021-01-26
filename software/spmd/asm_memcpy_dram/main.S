// This program copies data from DMEM to DRAM, and copies the data back from DRAM to DMEM.
// 1. initialize DMEM with sample data
// 2. copy from DMEM to DRAM
// 3. clear the DMEM
// 4. copy from DRAM to DMEM
// 5. validate the data in DMEM


#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"
#define N 1024

// allocate 4KB in DRAM
.section .dram, "aw"
  dram_arr: .space (N*4)

// initialize
.text
li x1, 0
li x2, 0
li x3, 0
li x4, 0
li x5, 0
li x6, 0
li x7, 0
li x8, 0
li x9, 0
li x10,0
li x11,0
li x12,0
li x13,0
li x14,0
li x15,0
li x16,0
li x17,0
li x18,0
li x19,0
li x20,0
li x21,0
li x22,0
li x23,0
li x24,0
li x25,0
li x26,0
li x27,0
li x28,0
li x29,0
li x30,0
li x31,0

fcvt.s.w f0, x0
fcvt.s.w f1, x0
fcvt.s.w f2, x0
fcvt.s.w f3, x0
fcvt.s.w f4, x0
fcvt.s.w f5, x0
fcvt.s.w f6, x0
fcvt.s.w f7, x0
fcvt.s.w f8, x0
fcvt.s.w f9, x0
fcvt.s.w f10,x0
fcvt.s.w f11,x0
fcvt.s.w f12,x0
fcvt.s.w f13,x0
fcvt.s.w f14,x0
fcvt.s.w f15,x0
fcvt.s.w f16,x0
fcvt.s.w f17,x0
fcvt.s.w f18,x0
fcvt.s.w f19,x0
fcvt.s.w f20,x0
fcvt.s.w f21,x0
fcvt.s.w f22,x0
fcvt.s.w f23,x0
fcvt.s.w f24,x0
fcvt.s.w f25,x0
fcvt.s.w f26,x0
fcvt.s.w f27,x0
fcvt.s.w f28,x0
fcvt.s.w f29,x0
fcvt.s.w f30,x0
fcvt.s.w f31,x0

// initialize DMEM with 0.0~1023.0
li t0, 0
li t1, 0
li t2, N
init_loop:
  fcvt.s.w f0, t1
  addi t1, t1, 1
  fsw f0, 0(t0)
  addi t0, t0, 4
  bne t1, t2, init_loop


// copy from DMEM to DRAM
li t0, 0
la t1, dram_arr
li t2, 0
li t3, (N/32)
dmem_to_dram_loop:
  flw f0, 0(t0)
  flw f1, 4(t0)
  flw f2, 8(t0)
  flw f3, 12(t0)
  flw f4, 16(t0)
  flw f5, 20(t0)
  flw f6, 24(t0)
  flw f7, 28(t0)
  flw f8, 32(t0)
  flw f9, 36(t0)
  flw f10, 40(t0)
  flw f11, 44(t0)
  flw f12, 48(t0)
  flw f13, 52(t0)
  flw f14, 56(t0)
  flw f15, 60(t0)
  flw f16, 64(t0)
  flw f17, 68(t0)
  flw f18, 72(t0)
  flw f19, 76(t0)
  flw f20, 80(t0)
  flw f21, 84(t0)
  flw f22, 88(t0)
  flw f23, 92(t0)
  flw f24, 96(t0)
  flw f25, 100(t0)
  flw f26, 104(t0)
  flw f27, 108(t0)
  flw f28, 112(t0)
  flw f29, 116(t0)
  flw f30, 120(t0)
  flw f31, 124(t0)
  fsw f0, 0(t1)
  fsw f1, 4(t1)
  fsw f2, 8(t1)
  fsw f3, 12(t1)
  fsw f4, 16(t1)
  fsw f5, 20(t1)
  fsw f6, 24(t1)
  fsw f7, 28(t1)
  fsw f8, 32(t1)
  fsw f9, 36(t1)
  fsw f10, 40(t1)
  fsw f11, 44(t1)
  fsw f12, 48(t1)
  fsw f13, 52(t1)
  fsw f14, 56(t1)
  fsw f15, 60(t1)
  fsw f16, 64(t1)
  fsw f17, 68(t1)
  fsw f18, 72(t1)
  fsw f19, 76(t1)
  fsw f20, 80(t1)
  fsw f21, 84(t1)
  fsw f22, 88(t1)
  fsw f23, 92(t1)
  fsw f24, 96(t1)
  fsw f25, 100(t1)
  fsw f26, 104(t1)
  fsw f27, 108(t1)
  fsw f28, 112(t1)
  fsw f29, 116(t1)
  fsw f30, 120(t1)
  fsw f31, 124(t1)
  addi t0, t0, 128
  addi t1, t1, 128
  addi t2, t2, 1
  bne t2, t3, dmem_to_dram_loop

// clear DMEM
li t0, 0
li t1, 0
li t2, N
fcvt.s.w f0, x0
clear_dmem_loop:
  fsw f0, 0(t0)
  addi t0, t0, 4
  addi t1, t1, 1
  bne t1, t2, clear_dmem_loop

// copy from DRAM to DMEM
li t0, 0
la t1, dram_arr
li t2, 0
li t3, (N/32)
dram_to_dmem_loop:
  flw f0, 0(t1)
  flw f1, 4(t1)
  flw f2, 8(t1)
  flw f3, 12(t1)
  flw f4, 16(t1)
  flw f5, 20(t1)
  flw f6, 24(t1)
  flw f7, 28(t1)
  flw f8, 32(t1)
  flw f9, 36(t1)
  flw f10, 40(t1)
  flw f11, 44(t1)
  flw f12, 48(t1)
  flw f13, 52(t1)
  flw f14, 56(t1)
  flw f15, 60(t1)
  flw f16, 64(t1)
  flw f17, 68(t1)
  flw f18, 72(t1)
  flw f19, 76(t1)
  flw f20, 80(t1)
  flw f21, 84(t1)
  flw f22, 88(t1)
  flw f23, 92(t1)
  flw f24, 96(t1)
  flw f25, 100(t1)
  flw f26, 104(t1)
  flw f27, 108(t1)
  flw f28, 112(t1)
  flw f29, 116(t1)
  flw f30, 120(t1)
  flw f31, 124(t1)
  fsw f0, 0(t0)
  fsw f1, 4(t0)
  fsw f2, 8(t0)
  fsw f3, 12(t0)
  fsw f4, 16(t0)
  fsw f5, 20(t0)
  fsw f6, 24(t0)
  fsw f7, 28(t0)
  fsw f8, 32(t0)
  fsw f9, 36(t0)
  fsw f10, 40(t0)
  fsw f11, 44(t0)
  fsw f12, 48(t0)
  fsw f13, 52(t0)
  fsw f14, 56(t0)
  fsw f15, 60(t0)
  fsw f16, 64(t0)
  fsw f17, 68(t0)
  fsw f18, 72(t0)
  fsw f19, 76(t0)
  fsw f20, 80(t0)
  fsw f21, 84(t0)
  fsw f22, 88(t0)
  fsw f23, 92(t0)
  fsw f24, 96(t0)
  fsw f25, 100(t0)
  fsw f26, 104(t0)
  fsw f27, 108(t0)
  fsw f28, 112(t0)
  fsw f29, 116(t0)
  fsw f30, 120(t0)
  fsw f31, 124(t0)
  addi t0, t0, 128
  addi t1, t1, 128
  addi t2, t2, 1
  bne t2, t3, dram_to_dmem_loop

// validate
li t0, 0
li t1, 0
li t2, N
validate_loop:
  flw f0, 0(t0)
  fcvt.w.s t3, f0
  bne t3, t1, fail
  addi t0, t0, 4
  addi t1, t1, 1
  bne t1, t2, validate_loop

 
pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  beq x0, x0, pass_loop

fail:
  bsg_asm_fail(IO_X_INDEX, 0)

fail_loop:
  beq x0, x0, fail_loop
