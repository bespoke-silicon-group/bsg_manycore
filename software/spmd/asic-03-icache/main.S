// Test every icache location - program is exactly 1024 instructions;
// it does not test icache miss;

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

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


li s0, 10 // loop counter

loop:
  // t0
  addi t0, t0,  1
  addi t0, t0, -1
  addi t0, t0,  2
  addi t0, t0, -2
  addi t0, t0,  4
  addi t0, t0, -4
  addi t0, t0,  8
  addi t0, t0, -8
  addi t0, t0,  16
  addi t0, t0, -16
  addi t0, t0,  32
  addi t0, t0, -32
  addi t0, t0,  64
  addi t0, t0, -64
  addi t0, t0,  128
  addi t0, t0, -128
  addi t0, t0,  256
  addi t0, t0, -256
  addi t0, t0,  512
  addi t0, t0, -512
  addi t0, t0,  1024
  addi t0, t0, -1024
  // check t0 equals zero;
  bne t0, x0, fail

  // t1
  addi t1, t1,  1
  addi t1, t1, -1
  addi t1, t1,  2
  addi t1, t1, -2
  addi t1, t1,  4
  addi t1, t1, -4
  addi t1, t1,  8
  addi t1, t1, -8
  addi t1, t1,  16
  addi t1, t1, -16
  addi t1, t1,  32
  addi t1, t1, -32
  addi t1, t1,  64
  addi t1, t1, -64
  addi t1, t1,  128
  addi t1, t1, -128
  addi t1, t1,  256
  addi t1, t1, -256
  addi t1, t1,  512
  addi t1, t1, -512
  addi t1, t1,  1024
  addi t1, t1, -1024
  // check t1 equals zero;
  bne t1, x0, fail

  // t2
  addi t2, t2,  1
  addi t2, t2, -1
  addi t2, t2,  2
  addi t2, t2, -2
  addi t2, t2,  4
  addi t2, t2, -4
  addi t2, t2,  8
  addi t2, t2, -8
  addi t2, t2,  16
  addi t2, t2, -16
  addi t2, t2,  32
  addi t2, t2, -32
  addi t2, t2,  64
  addi t2, t2, -64
  addi t2, t2,  128
  addi t2, t2, -128
  addi t2, t2,  256
  addi t2, t2, -256
  addi t2, t2,  512
  addi t2, t2, -512
  addi t2, t2,  1024
  addi t2, t2, -1024
  // check t2 equals zero;
  bne t2, x0, fail

  // t3
  addi t3, t3,  1
  addi t3, t3, -1
  addi t3, t3,  2
  addi t3, t3, -2
  addi t3, t3,  4
  addi t3, t3, -4
  addi t3, t3,  8
  addi t3, t3, -8
  addi t3, t3,  16
  addi t3, t3, -16
  addi t3, t3,  32
  addi t3, t3, -32
  addi t3, t3,  64
  addi t3, t3, -64
  addi t3, t3,  128
  addi t3, t3, -128
  addi t3, t3,  256
  addi t3, t3, -256
  addi t3, t3,  512
  addi t3, t3, -512
  addi t3, t3,  1024
  addi t3, t3, -1024
  // check t3 equals zero;
  bne t3, x0, fail

  // t4
  addi t4, t4,  1
  addi t4, t4, -1
  addi t4, t4,  2
  addi t4, t4, -2
  addi t4, t4,  4
  addi t4, t4, -4
  addi t4, t4,  8
  addi t4, t4, -8
  addi t4, t4,  16
  addi t4, t4, -16
  addi t4, t4,  32
  addi t4, t4, -32
  addi t4, t4,  64
  addi t4, t4, -64
  addi t4, t4,  128
  addi t4, t4, -128
  addi t4, t4,  256
  addi t4, t4, -256
  addi t4, t4,  512
  addi t4, t4, -512
  addi t4, t4,  1024
  addi t4, t4, -1024
  // check equals zero;
  bne t4, x0, fail

  // t5
  addi t5, t5,  1
  addi t5, t5, -1
  addi t5, t5,  2
  addi t5, t5, -2
  addi t5, t5,  4
  addi t5, t5, -4
  addi t5, t5,  8
  addi t5, t5, -8
  addi t5, t5,  16
  addi t5, t5, -16
  addi t5, t5,  32
  addi t5, t5, -32
  addi t5, t5,  64
  addi t5, t5, -64
  addi t5, t5,  128
  addi t5, t5, -128
  addi t5, t5,  256
  addi t5, t5, -256
  addi t5, t5,  512
  addi t5, t5, -512
  addi t5, t5,  1024
  addi t5, t5, -1024
  // check equals zero;
  bne t5, x0, fail

  // t6
  addi t6, t6,  1
  addi t6, t6, -1
  addi t6, t6,  2
  addi t6, t6, -2
  addi t6, t6,  4
  addi t6, t6, -4
  addi t6, t6,  8
  addi t6, t6, -8
  addi t6, t6,  16
  addi t6, t6, -16
  addi t6, t6,  32
  addi t6, t6, -32
  addi t6, t6,  64
  addi t6, t6, -64
  addi t6, t6,  128
  addi t6, t6, -128
  addi t6, t6,  256
  addi t6, t6, -256
  addi t6, t6,  512
  addi t6, t6, -512
  addi t6, t6,  1024
  addi t6, t6, -1024
  // check equals zero;
  bne t6, x0, fail

  // s1
  addi t6, t6,  1
  addi t6, t6, -1
  addi t6, t6,  2
  addi t6, t6, -2
  addi t6, t6,  4
  addi t6, t6, -4
  addi t6, t6,  8
  addi t6, t6, -8
  addi t6, t6,  16
  addi t6, t6, -16
  addi t6, t6,  32
  addi t6, t6, -32
  addi t6, t6,  64
  addi t6, t6, -64
  addi t6, t6,  128
  addi t6, t6, -128
  addi t6, t6,  256
  addi t6, t6, -256
  addi t6, t6,  512
  addi t6, t6, -512
  addi t6, t6,  1024
  addi t6, t6, -1024
  // check equals zero;
  bne t6, x0, fail

  addi s1, s1, 1
  addi s1, s1, -1
  addi s1, s1, 2
  addi s1, s1, -2
  addi s1, s1, 4
  addi s1, s1, -4
  addi s1, s1, 8
  addi s1, s1, -8
  addi s1, s1, 16
  addi s1, s1, -16
  addi s1, s1, 32
  addi s1, s1, -32
  addi s1, s1, 64
  addi s1, s1, -64
  addi s1, s1, 128
  addi s1, s1, -128
  addi s1, s1, 256
  addi s1, s1, -256
  addi s1, s1, 512
  addi s1, s1, -512
  addi s1, s1, 1024
  addi s1, s1, -1024
  bne s1, x0, fail

  addi s2, s2, 1
  addi s2, s2, -1
  addi s2, s2, 2
  addi s2, s2, -2
  addi s2, s2, 4
  addi s2, s2, -4
  addi s2, s2, 8
  addi s2, s2, -8
  addi s2, s2, 16
  addi s2, s2, -16
  addi s2, s2, 32
  addi s2, s2, -32
  addi s2, s2, 64
  addi s2, s2, -64
  addi s2, s2, 128
  addi s2, s2, -128
  addi s2, s2, 256
  addi s2, s2, -256
  addi s2, s2, 512
  addi s2, s2, -512
  addi s2, s2, 1024
  addi s2, s2, -1024
  bne s2, x0, fail

  addi s3, s3, 1
  addi s3, s3, -1
  addi s3, s3, 2
  addi s3, s3, -2
  addi s3, s3, 4
  addi s3, s3, -4
  addi s3, s3, 8
  addi s3, s3, -8
  addi s3, s3, 16
  addi s3, s3, -16
  addi s3, s3, 32
  addi s3, s3, -32
  addi s3, s3, 64
  addi s3, s3, -64
  addi s3, s3, 128
  addi s3, s3, -128
  addi s3, s3, 256
  addi s3, s3, -256
  addi s3, s3, 512
  addi s3, s3, -512
  addi s3, s3, 1024
  addi s3, s3, -1024
  bne s3, x0, fail

  addi s4, s4, 1
  addi s4, s4, -1
  addi s4, s4, 2
  addi s4, s4, -2
  addi s4, s4, 4
  addi s4, s4, -4
  addi s4, s4, 8
  addi s4, s4, -8
  addi s4, s4, 16
  addi s4, s4, -16
  addi s4, s4, 32
  addi s4, s4, -32
  addi s4, s4, 64
  addi s4, s4, -64
  addi s4, s4, 128
  addi s4, s4, -128
  addi s4, s4, 256
  addi s4, s4, -256
  addi s4, s4, 512
  addi s4, s4, -512
  addi s4, s4, 1024
  addi s4, s4, -1024
  bne s4, x0, fail

  addi s5, s5, 1
  addi s5, s5, -1
  addi s5, s5, 2
  addi s5, s5, -2
  addi s5, s5, 4
  addi s5, s5, -4
  addi s5, s5, 8
  addi s5, s5, -8
  addi s5, s5, 16
  addi s5, s5, -16
  addi s5, s5, 32
  addi s5, s5, -32
  addi s5, s5, 64
  addi s5, s5, -64
  addi s5, s5, 128
  addi s5, s5, -128
  addi s5, s5, 256
  addi s5, s5, -256
  addi s5, s5, 512
  addi s5, s5, -512
  addi s5, s5, 1024
  addi s5, s5, -1024
  bne s5, x0, fail

  addi s6, s6, 1
  addi s6, s6, -1
  addi s6, s6, 2
  addi s6, s6, -2
  addi s6, s6, 4
  addi s6, s6, -4
  addi s6, s6, 8
  addi s6, s6, -8
  addi s6, s6, 16
  addi s6, s6, -16
  addi s6, s6, 32
  addi s6, s6, -32
  addi s6, s6, 64
  addi s6, s6, -64
  addi s6, s6, 128
  addi s6, s6, -128
  addi s6, s6, 256
  addi s6, s6, -256
  addi s6, s6, 512
  addi s6, s6, -512
  addi s6, s6, 1024
  addi s6, s6, -1024
  bne s6, x0, fail

  addi s7, s7, 1
  addi s7, s7, -1
  addi s7, s7, 2
  addi s7, s7, -2
  addi s7, s7, 4
  addi s7, s7, -4
  addi s7, s7, 8
  addi s7, s7, -8
  addi s7, s7, 16
  addi s7, s7, -16
  addi s7, s7, 32
  addi s7, s7, -32
  addi s7, s7, 64
  addi s7, s7, -64
  addi s7, s7, 128
  addi s7, s7, -128
  addi s7, s7, 256
  addi s7, s7, -256
  addi s7, s7, 512
  addi s7, s7, -512
  addi s7, s7, 1024
  addi s7, s7, -1024
  bne s7, x0, fail

  addi s8, s8, 1
  addi s8, s8, -1
  addi s8, s8, 2
  addi s8, s8, -2
  addi s8, s8, 4
  addi s8, s8, -4
  addi s8, s8, 8
  addi s8, s8, -8
  addi s8, s8, 16
  addi s8, s8, -16
  addi s8, s8, 32
  addi s8, s8, -32
  addi s8, s8, 64
  addi s8, s8, -64
  addi s8, s8, 128
  addi s8, s8, -128
  addi s8, s8, 256
  addi s8, s8, -256
  addi s8, s8, 512
  addi s8, s8, -512
  addi s8, s8, 1024
  addi s8, s8, -1024
  bne s8, x0, fail

  addi s9, s9, 1
  addi s9, s9, -1
  addi s9, s9, 2
  addi s9, s9, -2
  addi s9, s9, 4
  addi s9, s9, -4
  addi s9, s9, 8
  addi s9, s9, -8
  addi s9, s9, 16
  addi s9, s9, -16
  addi s9, s9, 32
  addi s9, s9, -32
  addi s9, s9, 64
  addi s9, s9, -64
  addi s9, s9, 128
  addi s9, s9, -128
  addi s9, s9, 256
  addi s9, s9, -256
  addi s9, s9, 512
  addi s9, s9, -512
  addi s9, s9, 1024
  addi s9, s9, -1024
  bne s9, x0, fail

  addi s10, s10, 1
  addi s10, s10, -1
  addi s10, s10, 2
  addi s10, s10, -2
  addi s10, s10, 4
  addi s10, s10, -4
  addi s10, s10, 8
  addi s10, s10, -8
  addi s10, s10, 16
  addi s10, s10, -16
  addi s10, s10, 32
  addi s10, s10, -32
  addi s10, s10, 64
  addi s10, s10, -64
  addi s10, s10, 128
  addi s10, s10, -128
  addi s10, s10, 256
  addi s10, s10, -256
  addi s10, s10, 512
  addi s10, s10, -512
  addi s10, s10, 1024
  addi s10, s10, -1024
  bne s10, x0, fail

  addi s11, s11, 1
  addi s11, s11, -1
  addi s11, s11, 2
  addi s11, s11, -2
  addi s11, s11, 4
  addi s11, s11, -4
  addi s11, s11, 8
  addi s11, s11, -8
  addi s11, s11, 16
  addi s11, s11, -16
  addi s11, s11, 32
  addi s11, s11, -32
  addi s11, s11, 64
  addi s11, s11, -64
  addi s11, s11, 128
  addi s11, s11, -128
  addi s11, s11, 256
  addi s11, s11, -256
  addi s11, s11, 512
  addi s11, s11, -512
  addi s11, s11, 1024
  addi s11, s11, -1024
  bne s11, x0, fail

  // t0
  addi t0, t0,  1
  addi t0, t0, -1
  addi t0, t0,  2
  addi t0, t0, -2
  addi t0, t0,  4
  addi t0, t0, -4
  addi t0, t0,  8
  addi t0, t0, -8
  addi t0, t0,  16
  addi t0, t0, -16
  addi t0, t0,  32
  addi t0, t0, -32
  addi t0, t0,  64
  addi t0, t0, -64
  addi t0, t0,  128
  addi t0, t0, -128
  addi t0, t0,  256
  addi t0, t0, -256
  addi t0, t0,  512
  addi t0, t0, -512
  addi t0, t0,  1024
  addi t0, t0, -1024
  // check t0 equals zero;
  bne t0, x0, fail


  // t1
  addi t1, t1,  1
  addi t1, t1, -1
  addi t1, t1,  2
  addi t1, t1, -2
  addi t1, t1,  4
  addi t1, t1, -4
  addi t1, t1,  8
  addi t1, t1, -8
  addi t1, t1,  16
  addi t1, t1, -16
  addi t1, t1,  32
  addi t1, t1, -32
  addi t1, t1,  64
  addi t1, t1, -64
  addi t1, t1,  128
  addi t1, t1, -128
  addi t1, t1,  256
  addi t1, t1, -256
  addi t1, t1,  512
  addi t1, t1, -512
  addi t1, t1,  1024
  addi t1, t1, -1024
  // check t1 equals zero;
  bne t1, x0, fail

  // t2
  addi t2, t2,  1
  addi t2, t2, -1
  addi t2, t2,  2
  addi t2, t2, -2
  addi t2, t2,  4
  addi t2, t2, -4
  addi t2, t2,  8
  addi t2, t2, -8
  addi t2, t2,  16
  addi t2, t2, -16
  addi t2, t2,  32
  addi t2, t2, -32
  addi t2, t2,  64
  addi t2, t2, -64
  addi t2, t2,  128
  addi t2, t2, -128
  addi t2, t2,  256
  addi t2, t2, -256
  addi t2, t2,  512
  addi t2, t2, -512
  addi t2, t2,  1024
  addi t2, t2, -1024
  // check t2 equals zero;
  bne t2, x0, fail

  // t3
  addi t3, t3,  1
  addi t3, t3, -1
  addi t3, t3,  2
  addi t3, t3, -2
  addi t3, t3,  4
  addi t3, t3, -4
  addi t3, t3,  8
  addi t3, t3, -8
  addi t3, t3,  16
  addi t3, t3, -16
  addi t3, t3,  32
  addi t3, t3, -32
  addi t3, t3,  64
  addi t3, t3, -64
  addi t3, t3,  128
  addi t3, t3, -128
  addi t3, t3,  256
  addi t3, t3, -256
  addi t3, t3,  512
  addi t3, t3, -512
  addi t3, t3,  1024
  addi t3, t3, -1024
  // check t3 equals zero;
  bne t3, x0, fail

  // t4
  addi t4, t4,  1
  addi t4, t4, -1
  addi t4, t4,  2
  addi t4, t4, -2
  addi t4, t4,  4
  addi t4, t4, -4
  addi t4, t4,  8
  addi t4, t4, -8
  addi t4, t4,  16
  addi t4, t4, -16
  addi t4, t4,  32
  addi t4, t4, -32
  addi t4, t4,  64
  addi t4, t4, -64
  addi t4, t4,  128
  addi t4, t4, -128
  addi t4, t4,  256
  addi t4, t4, -256
  addi t4, t4,  512
  addi t4, t4, -512
  addi t4, t4,  1024
  addi t4, t4, -1024
  // check equals zero;
  bne t4, x0, fail

  // t5
  addi t5, t5,  1
  addi t5, t5, -1
  addi t5, t5,  2
  addi t5, t5, -2
  addi t5, t5,  4
  addi t5, t5, -4
  addi t5, t5,  8
  addi t5, t5, -8
  addi t5, t5,  16
  addi t5, t5, -16
  addi t5, t5,  32
  addi t5, t5, -32
  addi t5, t5,  64
  addi t5, t5, -64
  addi t5, t5,  128
  addi t5, t5, -128
  addi t5, t5,  256
  addi t5, t5, -256
  addi t5, t5,  512
  addi t5, t5, -512
  addi t5, t5,  1024
  addi t5, t5, -1024
  // check equals zero;
  bne t5, x0, fail

  // t6
  addi t6, t6,  1
  addi t6, t6, -1
  addi t6, t6,  2
  addi t6, t6, -2
  addi t6, t6,  4
  addi t6, t6, -4
  addi t6, t6,  8
  addi t6, t6, -8
  addi t6, t6,  16
  addi t6, t6, -16
  addi t6, t6,  32
  addi t6, t6, -32
  addi t6, t6,  64
  addi t6, t6, -64
  addi t6, t6,  128
  addi t6, t6, -128
  addi t6, t6,  256
  addi t6, t6, -256
  addi t6, t6,  512
  addi t6, t6, -512
  addi t6, t6,  1024
  addi t6, t6, -1024
  // check equals zero;
  bne t6, x0, fail


  // s1
  addi t6, t6,  1
  addi t6, t6, -1
  addi t6, t6,  2
  addi t6, t6, -2
  addi t6, t6,  4
  addi t6, t6, -4
  addi t6, t6,  8
  addi t6, t6, -8
  addi t6, t6,  16
  addi t6, t6, -16
  addi t6, t6,  32
  addi t6, t6, -32
  addi t6, t6,  64
  addi t6, t6, -64
  addi t6, t6,  128
  addi t6, t6, -128
  addi t6, t6,  256
  addi t6, t6, -256
  addi t6, t6,  512
  addi t6, t6, -512
  addi t6, t6,  1024
  addi t6, t6, -1024
  // check equals zero;
  bne t6, x0, fail

  addi s1, s1, 1
  addi s1, s1, -1
  addi s1, s1, 2
  addi s1, s1, -2
  addi s1, s1, 4
  addi s1, s1, -4
  addi s1, s1, 8
  addi s1, s1, -8
  addi s1, s1, 16
  addi s1, s1, -16
  addi s1, s1, 32
  addi s1, s1, -32
  addi s1, s1, 64
  addi s1, s1, -64
  addi s1, s1, 128
  addi s1, s1, -128
  addi s1, s1, 256
  addi s1, s1, -256
  addi s1, s1, 512
  addi s1, s1, -512
  addi s1, s1, 1024
  addi s1, s1, -1024
  bne s1, x0, fail

  addi s2, s2, 1
  addi s2, s2, -1
  addi s2, s2, 2
  addi s2, s2, -2
  addi s2, s2, 4
  addi s2, s2, -4
  addi s2, s2, 8
  addi s2, s2, -8
  addi s2, s2, 16
  addi s2, s2, -16
  addi s2, s2, 32
  addi s2, s2, -32
  addi s2, s2, 64
  addi s2, s2, -64
  addi s2, s2, 128
  addi s2, s2, -128
  addi s2, s2, 256
  addi s2, s2, -256
  addi s2, s2, 512
  addi s2, s2, -512
  addi s2, s2, 1024
  addi s2, s2, -1024
  bne s2, x0, fail

  addi s3, s3, 1
  addi s3, s3, -1
  addi s3, s3, 2
  addi s3, s3, -2
  addi s3, s3, 4
  addi s3, s3, -4
  addi s3, s3, 8
  addi s3, s3, -8
  addi s3, s3, 16
  addi s3, s3, -16
  addi s3, s3, 32
  addi s3, s3, -32
  addi s3, s3, 64
  addi s3, s3, -64
  addi s3, s3, 128
  addi s3, s3, -128
  addi s3, s3, 256
  addi s3, s3, -256
  addi s3, s3, 512
  addi s3, s3, -512
  addi s3, s3, 1024
  addi s3, s3, -1024
  bne s3, x0, fail

  addi s4, s4, 1
  addi s4, s4, -1
  addi s4, s4, 2
  addi s4, s4, -2
  addi s4, s4, 4
  addi s4, s4, -4
  addi s4, s4, 8
  addi s4, s4, -8
  addi s4, s4, 16
  addi s4, s4, -16
  addi s4, s4, 32
  addi s4, s4, -32
  addi s4, s4, 64
  addi s4, s4, -64
  addi s4, s4, 128
  addi s4, s4, -128
  addi s4, s4, 256
  addi s4, s4, -256
  addi s4, s4, 512
  addi s4, s4, -512
  addi s4, s4, 1024
  addi s4, s4, -1024
  bne s4, x0, fail

  addi s5, s5, 1
  addi s5, s5, -1
  addi s5, s5, 2
  addi s5, s5, -2
  addi s5, s5, 4
  addi s5, s5, -4
  addi s5, s5, 8
  addi s5, s5, -8
  addi s5, s5, 16
  addi s5, s5, -16
  addi s5, s5, 32
  addi s5, s5, -32
  addi s5, s5, 64
  addi s5, s5, -64
  addi s5, s5, 128
  addi s5, s5, -128
  addi s5, s5, 256
  addi s5, s5, -256
  addi s5, s5, 512
  addi s5, s5, -512
  addi s5, s5, 1024
  addi s5, s5, -1024
  bne s5, x0, fail

  addi s6, s6, 1
  addi s6, s6, -1
  addi s6, s6, 2
  addi s6, s6, -2
  addi s6, s6, 4
  addi s6, s6, -4
  addi s6, s6, 8
  addi s6, s6, -8
  addi s6, s6, 16
  addi s6, s6, -16
  addi s6, s6, 32
  addi s6, s6, -32
  addi s6, s6, 64
  addi s6, s6, -64
  addi s6, s6, 128
  addi s6, s6, -128
  addi s6, s6, 256
  addi s6, s6, -256
  addi s6, s6, 512
  addi s6, s6, -512
  addi s6, s6, 1024
  addi s6, s6, -1024
  bne s6, x0, fail

  addi s7, s7, 1
  addi s7, s7, -1
  addi s7, s7, 2
  addi s7, s7, -2
  addi s7, s7, 4
  addi s7, s7, -4
  addi s7, s7, 8
  addi s7, s7, -8
  addi s7, s7, 16
  addi s7, s7, -16
  addi s7, s7, 32
  addi s7, s7, -32
  addi s7, s7, 64
  addi s7, s7, -64
  addi s7, s7, 128
  addi s7, s7, -128
  addi s7, s7, 256
  addi s7, s7, -256
  addi s7, s7, 512
  addi s7, s7, -512
  addi s7, s7, 1024
  addi s7, s7, -1024
  bne s7, x0, fail

  addi s8, s8, 1
  addi s8, s8, -1
  addi s8, s8, 2
  addi s8, s8, -2
  addi s8, s8, 4
  addi s8, s8, -4
  addi s8, s8, 8
  addi s8, s8, -8
  addi s8, s8, 16
  addi s8, s8, -16
  addi s8, s8, 32
  addi s8, s8, -32
  addi s8, s8, 64
  addi s8, s8, -64
  addi s8, s8, 128
  addi s8, s8, -128
  addi s8, s8, 256
  addi s8, s8, -256
  addi s8, s8, 512
  addi s8, s8, -512
  addi s8, s8, 1024
  addi s8, s8, -1024
  bne s8, x0, fail

  addi s9, s9, 1
  addi s9, s9, -1
  addi s9, s9, 2
  addi s9, s9, -2
  addi s9, s9, 4
  addi s9, s9, -4
  addi s9, s9, 8
  addi s9, s9, -8
  addi s9, s9, 16
  addi s9, s9, -16
  addi s9, s9, 32
  addi s9, s9, -32
  addi s9, s9, 64
  addi s9, s9, -64
  addi s9, s9, 128
  addi s9, s9, -128
  addi s9, s9, 256
  addi s9, s9, -256
  addi s9, s9, 512
  addi s9, s9, -512
  addi s9, s9, 1024
  addi s9, s9, -1024
  bne s9, x0, fail

  addi s10, s10, 1
  addi s10, s10, -1
  addi s10, s10, 2
  addi s10, s10, -2
  addi s10, s10, 4
  addi s10, s10, -4
  addi s10, s10, 8
  addi s10, s10, -8
  addi s10, s10, 16
  addi s10, s10, -16
  addi s10, s10, 32
  addi s10, s10, -32
  addi s10, s10, 64
  addi s10, s10, -64
  addi s10, s10, 128
  addi s10, s10, -128
  addi s10, s10, 256
  addi s10, s10, -256
  addi s10, s10, 512
  addi s10, s10, -512
  addi s10, s10, 1024
  addi s10, s10, -1024
  bne s10, x0, fail

  addi s11, s11, 1
  addi s11, s11, -1
  addi s11, s11, 2
  addi s11, s11, -2
  addi s11, s11, 4
  addi s11, s11, -4
  addi s11, s11, 8
  addi s11, s11, -8
  addi s11, s11, 16
  addi s11, s11, -16
  addi s11, s11, 32
  addi s11, s11, -32
  addi s11, s11, 64
  addi s11, s11, -64
  addi s11, s11, 128
  addi s11, s11, -128
  addi s11, s11, 256
  addi s11, s11, -256
  addi s11, s11, 512
  addi s11, s11, -512
  addi s11, s11, 1024
  addi s11, s11, -1024
  bne s11, x0, fail

  // t0
  addi t0, t0,  1
  addi t0, t0, -1
  addi t0, t0,  2
  addi t0, t0, -2
  addi t0, t0,  4
  addi t0, t0, -4
  addi t0, t0,  8
  addi t0, t0, -8
  addi t0, t0,  16
  addi t0, t0, -16
  addi t0, t0,  32
  addi t0, t0, -32
  addi t0, t0,  64
  addi t0, t0, -64
  addi t0, t0,  128
  addi t0, t0, -128
  addi t0, t0,  256
  addi t0, t0, -256
  addi t0, t0,  512
  addi t0, t0, -512
  addi t0, t0,  1024
  addi t0, t0, -1024
  // check t0 equals zero;
  bne t0, x0, fail

  // t1
  addi t1, t1,  1
  addi t1, t1, -1
  addi t1, t1,  2
  addi t1, t1, -2
  addi t1, t1,  4
  addi t1, t1, -4
  addi t1, t1,  8
  addi t1, t1, -8
  addi t1, t1,  16
  addi t1, t1, -16
  addi t1, t1,  32
  addi t1, t1, -32
  addi t1, t1,  64
  addi t1, t1, -64
  addi t1, t1,  128
  addi t1, t1, -128
  addi t1, t1,  256
  addi t1, t1, -256
  addi t1, t1,  512
  addi t1, t1, -512
  addi t1, t1,  1024
  addi t1, t1, -1024
  // check t1 equals zero;
  bne t1, x0, fail

  // t2
  addi t2, t2,  1
  addi t2, t2, -1
  addi t2, t2,  2
  addi t2, t2, -2
  addi t2, t2,  4
  addi t2, t2, -4
  addi t2, t2,  8
  addi t2, t2, -8
  addi t2, t2,  16
  addi t2, t2, -16
  addi t2, t2,  32
  addi t2, t2, -32
  addi t2, t2,  64
  addi t2, t2, -64
  addi t2, t2,  128
  addi t2, t2, -128
  addi t2, t2,  256
  addi t2, t2, -256
  addi t2, t2,  512
  addi t2, t2, -512
  addi t2, t2,  1024
  addi t2, t2, -1024
  // check t2 equals zero;
  bne t2, x0, fail

  // t3
  addi t3, t3,  1
  addi t3, t3, -1
  addi t3, t3,  2
  addi t3, t3, -2
  // check t3 equals zero;
  bne t3, x0, fail

  // decrement loop counter
  addi s0, s0, -1
  bne s0, x0, loop






pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  j fail_loop
