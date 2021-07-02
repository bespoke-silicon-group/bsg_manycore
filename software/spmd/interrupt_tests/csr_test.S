// Author: Tommy
// testing accessing mcsr using csr instructions.

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.text
.globl _start
_start:
  bsg_asm_init_regfile


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
