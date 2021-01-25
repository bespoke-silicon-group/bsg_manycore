// testing accessing mcsr using csr instructions.

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
.globl _start
_start:
li x1, 0
li x2, 4096*2-4
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


// test mstatus
li x1, 0x88
csrrw x0, mstatus, x1
csrrw x2, mstatus, x0
bne x1, x2, fail

csrrc x0, mstatus, x1
csrrc x2, mstatus, x0
bne x2, x0, fail

li x1, 0x80
csrrs x0, mstatus, x1
csrrs x2, mstatus, x0
bne x1, x2, fail

li x1, 0xff
csrrc x0, mstatus, x1
csrrc x2, mstatus, x0
bne x2, x0, fail


# test mepc
li x1, 0xbeef0
csrrw x0, mepc, x1
csrrw x2, mepc, x0
bne x2, x1, fail


# test mip
li x1, 0x30000
csrrw x0, mip, x1
csrrw x2, mip, x0
bne x1, x2, fail

csrrc x0, mip, x1
csrrc x2, mip, x0
bne x2, x0, fail




pass:
  bsg_asm_finish(IO_X_INDEX, 0)

pass_loop:
  beq x0, x0, pass_loop

fail:
  bsg_asm_fail(IO_X_INDEX, 0)

fail_loop:
  beq x0, x0, fail_loop
