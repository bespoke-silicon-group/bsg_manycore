#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.data
  float_dmem_arr: .space 64
.section .dram, "aw"
  float_dram_arr: .space 64

.text
main:
li x0, 0
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

init_test:
    li x1, 0X4019999A // 2.4
    li x2, 0X3E19999A // 0.15
    li x3, 0X406CCCCD // 3.7
    li x4, 0X40D55555 // 6.666666666666667
    li x5, 0XC1C55555 // -24.666666666666668
    fmv.s.x f1, x1
    fmv.s.x f2, x2
    fmv.s.x f3, x3
    fmv.s.x f4, x4
    fmv.s.x f5, x5

li x1, 0x00001000   // number of iterations
fma_test:
    fmadd.s f1, f1, f2, f3
    fmadd.s f1, f1, f2, f3
    fmadd.s f1, f1, f4, f5
    fmadd.s f1, f1, f4, f5

    fmadd.s f1, f1, f2, f3
    fmadd.s f1, f1, f4, f5

    fmadd.s f1, f1, f2, f3
    fmadd.s f1, f1, f2, f3
    fmadd.s f1, f1, f2, f3
    fmadd.s f1, f1, f4, f5
    fmadd.s f1, f1, f4, f5
    fmadd.s f1, f1, f4, f5

    fmadd.s f1, f1, f2, f3
    fmadd.s f1, f1, f2, f3
    fmadd.s f1, f1, f4, f5
    fmadd.s f1, f1, f4, f5

    addi x1, x1, -1
    bne x0, x1, fma_test

check:
    fmv.x.s x1, f1
    li x2, 0X40199AA3
    srli x3, x1, 4
    srli x4, x2, 4
    bne x3, x4, fail

pass:
  bsg_asm_finish(IO_X_INDEX,0)
  beq x0, x0, wait_forever
fail:
  bsg_asm_print_reg(IO_X_INDEX,x1)
  bsg_asm_print_reg(IO_X_INDEX,x2)
  bsg_asm_fail(IO_X_INDEX, 0)
wait_forever:
  beq x0, x0, wait_forever
