// This tests aims to expose the bug, where a residual credit packet in return FIFO causes a regfile corruption
// by the core misinterpreting the return FIFO full signal (assuming the output is valid by looking at full signal alone, when valid is actually low).


#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

.section .dram, "aw"
dram_ptr: .space 4

.text
  bsg_asm_init_regfile

test_init:
  la t0, dram_ptr
  li t1, 0
  addi t0, t0, (4*8*2)
  // setup x1 as deafbeef
  li x1, 0xdeadbeef
  j here0

here0:
  // value to store
  li x31, 0x11111101
  // send out remote load packets
  lw x2, 8(t0)
  lw x3, 16(t0)
  lw x4, 24(t0)
  // send out remote store packets
  sb x31, 40(t0)
  sb x31, 40(t0)
  sb x31, 48(t0)
  sb x31, 56(t0)

// while the core is executing a stream of addi, the remote load returns and starts backing up in the return FIFO.
// once the return FIFO is full, it will start force writing remote loads to regfile.
// Meantime, the credit packets with non-zero reg_id arrives without any bubble in between, so that
// the full signal is asserted, while the credit pkts are getting eaten by the endpoint.
here1:
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1
  addi t1, t1, 1

// make sure x1 is still deadbeef
check_x1:
  li t0, 0xdeadbeef
  bne t0, x1, fail
  

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
fail:
  bsg_asm_print_reg(IO_X_INDEX, s0)
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  j fail_loop
