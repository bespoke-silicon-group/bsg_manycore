// Test every icache location - program is exactly 1024 instructions;
// it does not test icache miss;

#include "bsg_manycore_arch.h"
#include "bsg_manycore_asm.h"

// initialize
.text
_start:
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



#define code_block \
addi x1, x1, 1; \
addi x1, x1, -1; \
addi x2, x2, 1; \
addi x2, x2, -1; \
addi x3, x3, 1; \
addi x3, x3, -1; \
addi x4, x4, 1; \
addi x4, x4, -1; \
addi x5, x5, 1; \
addi x5, x5, -1; \
addi x6, x6, 1; \
addi x6, x6, -1; \
addi x7, x7, 1; \
addi x7, x7, -1; \
addi x8, x8, 1; \
addi x8, x8, -1; \
addi x9, x9, 1; \
addi x9, x9, -1; \
addi x10, x10, 1; \
addi x10, x10, -1; \
addi x11, x11, 1; \
addi x11, x11, -1; \
addi x12, x12, 1; \
addi x12, x12, -1; \
addi x13, x13, 1; \
addi x13, x13, -1; \
addi x14, x14, 1; \
addi x14, x14, -1; \
addi x15, x15, 1; \
addi x15, x15, -1; \
addi x16, x16, 1; \
addi x16, x16, -1; \
addi x17, x17, 1; \
addi x17, x17, -1; \
addi x18, x18, 1; \
addi x18, x18, -1; \
addi x19, x19, 1; \
addi x19, x19, -1; \
addi x20, x20, 1; \
addi x20, x20, -1; \
addi x21, x21, 1; \
addi x21, x21, -1; \
addi x22, x22, 1; \
addi x22, x22, -1; \
addi x23, x23, 1; \
addi x23, x23, -1; \
addi x24, x24, 1; \
addi x24, x24, -1; \
addi x25, x25, 1; \
addi x25, x25, -1; \
addi x26, x26, 1; \
addi x26, x26, -1; \
addi x27, x27, 1; \
addi x27, x27, -1; \
addi x28, x28, 1; \
addi x28, x28, -1; \
addi x29, x29, 1; \
addi x29, x29, -1; \
addi x30, x30, 1; \
addi x30, x30, -1; \
addi x31, x31, 1; \
addi x31, x31, -1; \
addi x1, x1, 2; \
addi x1, x1, -2; \
addi x2, x2, 2; \
addi x2, x2, -2; \
addi x3, x3, 2; \
addi x3, x3, -2; \
addi x4, x4, 2; \
addi x4, x4, -2; \
addi x5, x5, 2; \
addi x5, x5, -2; \
addi x6, x6, 2; \
addi x6, x6, -2; \
addi x7, x7, 2; \
addi x7, x7, -2; \
addi x8, x8, 2; \
addi x8, x8, -2; \
addi x9, x9, 2; \
addi x9, x9, -2; \
addi x10, x10, 2; \
addi x10, x10, -2; \
addi x11, x11, 2; \
addi x11, x11, -2; \
addi x12, x12, 2; \
addi x12, x12, -2; \
addi x13, x13, 2; \
addi x13, x13, -2; \
addi x14, x14, 2; \
addi x14, x14, -2; \
addi x15, x15, 2; \
addi x15, x15, -2; \
addi x16, x16, 2; \
addi x16, x16, -2; \
addi x17, x17, 2; \
addi x17, x17, -2; \
addi x18, x18, 2; \
addi x18, x18, -2; \
addi x19, x19, 2; \
addi x19, x19, -2; \
addi x20, x20, 2; \
addi x20, x20, -2; \
addi x21, x21, 2; \
addi x21, x21, -2; \
addi x22, x22, 2; \
addi x22, x22, -2; \
addi x23, x23, 2; \
addi x23, x23, -2; \
addi x24, x24, 2; \
addi x24, x24, -2; \
addi x25, x25, 2; \
addi x25, x25, -2; \
addi x26, x26, 2; \
addi x26, x26, -2; \
addi x27, x27, 2; \
addi x27, x27, -2; \
addi x28, x28, 2; \
addi x28, x28, -2; \
addi x29, x29, 2; \
addi x29, x29, -2; \
addi x30, x30, 2; \
addi x30, x30, -2; \
addi x31, x31, 2; \
addi x31, x31, -2; \
addi x1, x1, 4; \
addi x1, x1, -4; \
addi x2, x2, 4; \
addi x2, x2, -4; \
addi x3, x3, 4; \
addi x3, x3, -4; \
addi x4, x4, 4; \
addi x4, x4, -4; \
addi x5, x5, 4; \
addi x5, x5, -4; \
addi x6, x6, 4; \
addi x6, x6, -4; \
addi x7, x7, 4; \
addi x7, x7, -4; \
addi x8, x8, 4; \
addi x8, x8, -4; \
addi x9, x9, 4; \
addi x9, x9, -4; \
addi x10, x10, 4; \
addi x10, x10, -4; \
addi x11, x11, 4; \
addi x11, x11, -4; \
addi x12, x12, 4; \
addi x12, x12, -4; \
addi x13, x13, 4; \
addi x13, x13, -4; \
addi x14, x14, 4; \
addi x14, x14, -4; \
addi x15, x15, 4; \
addi x15, x15, -4; \
addi x16, x16, 4; \
addi x16, x16, -4; \
addi x17, x17, 4; \
addi x17, x17, -4; \
addi x18, x18, 4; \
addi x18, x18, -4; \
addi x19, x19, 4; \
addi x19, x19, -4; \
addi x20, x20, 4; \
addi x20, x20, -4; \
addi x21, x21, 4; \
addi x21, x21, -4; \
addi x22, x22, 4; \
addi x22, x22, -4; \
addi x23, x23, 4; \
addi x23, x23, -4; \
addi x24, x24, 4; \
addi x24, x24, -4; \
addi x25, x25, 4; \
addi x25, x25, -4; \
addi x26, x26, 4; \
addi x26, x26, -4; \
addi x27, x27, 4; \
addi x27, x27, -4; \
addi x28, x28, 4; \
addi x28, x28, -4; \
addi x29, x29, 4; \
addi x29, x29, -4; \
addi x30, x30, 4; \
addi x30, x30, -4; \
addi x31, x31, 4; \
addi x31, x31, -4; \
addi x1, x1, 8; \
addi x1, x1, -8; \
addi x2, x2, 8; \
addi x2, x2, -8; \
addi x3, x3, 8; \
addi x3, x3, -8; \
addi x4, x4, 8; \
addi x4, x4, -8; \
addi x5, x5, 8; \
addi x5, x5, -8; \
addi x6, x6, 8; \
addi x6, x6, -8; \
addi x7, x7, 8; \
addi x7, x7, -8; \
addi x8, x8, 8; \
addi x8, x8, -8; \
addi x9, x9, 8; \
addi x9, x9, -8; \
addi x10, x10, 8; \
addi x10, x10, -8; \
addi x11, x11, 8; \
addi x11, x11, -8; \
addi x12, x12, 8; \
addi x12, x12, -8; \
addi x13, x13, 8; \
addi x13, x13, -8; \
addi x14, x14, 8; \
addi x14, x14, -8; \
addi x15, x15, 8; \
addi x15, x15, -8; \
addi x16, x16, 8; \
addi x16, x16, -8; \
addi x17, x17, 8; \
addi x17, x17, -8; \
addi x18, x18, 8; \
addi x18, x18, -8; \
addi x19, x19, 8; \
addi x19, x19, -8; \
addi x20, x20, 8; \
addi x20, x20, -8; \
addi x21, x21, 8; \
addi x21, x21, -8; \
addi x22, x22, 8; \
addi x22, x22, -8; \
addi x23, x23, 8; \
addi x23, x23, -8; \
addi x24, x24, 8; \
addi x24, x24, -8; \
addi x25, x25, 8; \
addi x25, x25, -8; \
addi x26, x26, 8; \
addi x26, x26, -8; \
addi x27, x27, 8; \
addi x27, x27, -8; \
addi x28, x28, 8; \
addi x28, x28, -8; \
addi x29, x29, 8; \
addi x29, x29, -8; \
addi x30, x30, 8; \
addi x30, x30, -8; \
addi x31, x31, 8; \
addi x31, x31, -8; \
addi x1, x1, 16; \
addi x1, x1, -16; \
addi x2, x2, 16; \
addi x2, x2, -16; \
addi x3, x3, 16; \
addi x3, x3, -16; \
addi x4, x4, 16; \
addi x4, x4, -16; \
addi x5, x5, 16; \
addi x5, x5, -16; \
addi x6, x6, 16; \
addi x6, x6, -16; \
addi x7, x7, 16; \
addi x7, x7, -16; \
addi x8, x8, 16; \
addi x8, x8, -16; \
addi x9, x9, 16; \
addi x9, x9, -16; \
addi x10, x10, 16; \
addi x10, x10, -16; \
addi x11, x11, 16; \
addi x11, x11, -16; \
addi x12, x12, 16; \
addi x12, x12, -16; \
addi x13, x13, 16; \
addi x13, x13, -16; \
addi x14, x14, 16; \
addi x14, x14, -16; \
addi x15, x15, 16; \
addi x15, x15, -16; \
addi x16, x16, 16; \
addi x16, x16, -16; \
addi x17, x17, 16; \
addi x17, x17, -16; \
addi x18, x18, 16; \
addi x18, x18, -16; \
addi x19, x19, 16; \
addi x19, x19, -16; \
addi x20, x20, 16; \
addi x20, x20, -16; \
addi x21, x21, 16; \
addi x21, x21, -16; \
addi x22, x22, 16; \
addi x22, x22, -16; \
addi x23, x23, 16; \
addi x23, x23, -16; \
addi x24, x24, 16; \
addi x24, x24, -16; \
addi x25, x25, 16; \
addi x25, x25, -16; \
addi x26, x26, 16; \
addi x26, x26, -16; \
addi x27, x27, 16; \
addi x27, x27, -16; \
addi x28, x28, 16; \
addi x28, x28, -16; \
addi x29, x29, 16; \
addi x29, x29, -16; \
addi x30, x30, 16; \
addi x30, x30, -16; \
addi x31, x31, 16; \
addi x31, x31, -16; \
addi x1, x1, 32; \
addi x1, x1, -32; \
addi x2, x2, 32; \
addi x2, x2, -32; \
addi x3, x3, 32; \
addi x3, x3, -32; \
addi x4, x4, 32; \
addi x4, x4, -32; \
addi x5, x5, 32; \
addi x5, x5, -32; \
addi x6, x6, 32; \
addi x6, x6, -32; \
addi x7, x7, 32; \
addi x7, x7, -32; \
addi x8, x8, 32; \
addi x8, x8, -32; \
addi x9, x9, 32; \
addi x9, x9, -32; \
addi x10, x10, 32; \
addi x10, x10, -32; \
addi x11, x11, 32; \
addi x11, x11, -32; \
addi x12, x12, 32; \
addi x12, x12, -32; \
addi x13, x13, 32; \
addi x13, x13, -32; \
addi x14, x14, 32; \
addi x14, x14, -32; \
addi x15, x15, 32; \
addi x15, x15, -32; \
addi x16, x16, 32; \
addi x16, x16, -32; \
addi x17, x17, 32; \
addi x17, x17, -32; \
addi x18, x18, 32; \
addi x18, x18, -32; \
addi x19, x19, 32; \
addi x19, x19, -32; \
addi x20, x20, 32; \
addi x20, x20, -32; \
addi x21, x21, 32; \
addi x21, x21, -32; \
addi x22, x22, 32; \
addi x22, x22, -32; \
addi x23, x23, 32; \
addi x23, x23, -32; \
addi x24, x24, 32; \
addi x24, x24, -32; \
addi x25, x25, 32; \
addi x25, x25, -32; \
addi x26, x26, 32; \
addi x26, x26, -32; \
addi x27, x27, 32; \
addi x27, x27, -32; \
addi x28, x28, 32; \
addi x28, x28, -32; \
addi x29, x29, 32; \
addi x29, x29, -32; \
addi x30, x30, 32; \
addi x30, x30, -32; \
addi x31, x31, 32; \
addi x31, x31, -32; \
addi x1, x1, 64; \
addi x1, x1, -64; \
addi x2, x2, 64; \
addi x2, x2, -64; \
addi x3, x3, 64; \
addi x3, x3, -64; \
addi x4, x4, 64; \
addi x4, x4, -64; \
addi x5, x5, 64; \
addi x5, x5, -64; \
addi x6, x6, 64; \
addi x6, x6, -64; \
addi x7, x7, 64; \
addi x7, x7, -64; \
addi x8, x8, 64; \
addi x8, x8, -64; \
addi x9, x9, 64; \
addi x9, x9, -64; \
addi x10, x10, 64; \
addi x10, x10, -64; \
addi x11, x11, 64; \
addi x11, x11, -64; \
addi x12, x12, 64; \
addi x12, x12, -64; \
addi x13, x13, 64; \
addi x13, x13, -64; \
addi x14, x14, 64; \
addi x14, x14, -64; \
addi x15, x15, 64; \
addi x15, x15, -64; \
addi x16, x16, 64; \
addi x16, x16, -64; \
addi x17, x17, 64; \
addi x17, x17, -64; \
addi x18, x18, 64; \
addi x18, x18, -64; \
addi x19, x19, 64; \
addi x19, x19, -64; \
addi x20, x20, 64; \
addi x20, x20, -64; \
addi x21, x21, 64; \
addi x21, x21, -64; \
addi x22, x22, 64; \
addi x22, x22, -64; \
addi x23, x23, 64; \
addi x23, x23, -64; \
addi x24, x24, 64; \
addi x24, x24, -64; \
addi x25, x25, 64; \
addi x25, x25, -64; \
addi x26, x26, 64; \
addi x26, x26, -64; \
addi x27, x27, 64; \
addi x27, x27, -64; \
addi x28, x28, 64; \
addi x28, x28, -64; \
addi x29, x29, 64; \
addi x29, x29, -64; \
addi x30, x30, 64; \
addi x30, x30, -64; \
addi x31, x31, 64; \
addi x31, x31, -64; \
addi x1, x1, 128; \
addi x1, x1, -128; \
addi x2, x2, 128; \
addi x2, x2, -128; \
addi x3, x3, 128; \
addi x3, x3, -128; \
addi x4, x4, 128; \
addi x4, x4, -128; \
addi x5, x5, 128; \
addi x5, x5, -128; \
addi x6, x6, 128; \
addi x6, x6, -128; \
addi x7, x7, 128; \
addi x7, x7, -128; \
addi x8, x8, 128; \
addi x8, x8, -128; \
addi x9, x9, 128; \
addi x9, x9, -128; \
addi x10, x10, 128; \
addi x10, x10, -128; \
addi x11, x11, 128; \
addi x11, x11, -128; \
addi x12, x12, 128; \
addi x12, x12, -128; \
addi x13, x13, 128; \
addi x13, x13, -128; \
addi x14, x14, 128; \
addi x14, x14, -128; \
addi x15, x15, 128; \
addi x15, x15, -128; \
addi x16, x16, 128; \
addi x16, x16, -128; \
addi x17, x17, 128; \
addi x17, x17, -128; \
addi x18, x18, 128; \
addi x18, x18, -128; \
addi x19, x19, 128; \
addi x19, x19, -128; \
addi x20, x20, 128; \
addi x20, x20, -128; \
addi x21, x21, 128; \
addi x21, x21, -128; \
addi x22, x22, 128; \
addi x22, x22, -128; \
addi x23, x23, 128; \
addi x23, x23, -128; \
addi x24, x24, 128; \
addi x24, x24, -128; \
addi x25, x25, 128; \
addi x25, x25, -128; \
addi x26, x26, 128; \
addi x26, x26, -128; \
addi x27, x27, 128; \
addi x27, x27, -128; \
addi x28, x28, 128; \
addi x28, x28, -128; \
addi x29, x29, 128; \
addi x29, x29, -128; \
addi x30, x30, 128; \
addi x30, x30, -128; \
addi x31, x31, 128; \
addi x31, x31, -128; \
addi x1, x1, 256; \
addi x1, x1, -256; \
addi x2, x2, 256; \
addi x2, x2, -256; \
addi x3, x3, 256; \
addi x3, x3, -256; \
addi x4, x4, 256; \
addi x4, x4, -256; \
addi x5, x5, 256; \
addi x5, x5, -256; \
addi x6, x6, 256; \
addi x6, x6, -256; \
addi x7, x7, 256; \
addi x7, x7, -256; \
addi x8, x8, 256; \
addi x8, x8, -256; \
addi x9, x9, 256; \
addi x9, x9, -256; \
addi x10, x10, 256; \
addi x10, x10, -256; \
addi x11, x11, 256; \
addi x11, x11, -256; \
addi x12, x12, 256; \
addi x12, x12, -256; \
addi x13, x13, 256; \
addi x13, x13, -256; \
addi x14, x14, 256; \
addi x14, x14, -256; \
addi x15, x15, 256; \
addi x15, x15, -256; \
addi x16, x16, 256; \
addi x16, x16, -256; \
addi x17, x17, 256; \
addi x17, x17, -256; \
addi x18, x18, 256; \
addi x18, x18, -256; \
addi x19, x19, 256; \
addi x19, x19, -256; \
addi x20, x20, 256; \
addi x20, x20, -256; \
addi x21, x21, 256; \
addi x21, x21, -256; \
addi x22, x22, 256; \
addi x22, x22, -256; \
addi x23, x23, 256; \
addi x23, x23, -256; \
addi x24, x24, 256; \
addi x24, x24, -256; \
addi x25, x25, 256; \
addi x25, x25, -256; \
addi x26, x26, 256; \
addi x26, x26, -256; \
addi x27, x27, 256; \
addi x27, x27, -256; \
addi x28, x28, 256; \
addi x28, x28, -256; \
addi x29, x29, 256; \
addi x29, x29, -256; \
addi x30, x30, 256; \
addi x30, x30, -256; \
addi x31, x31, 256; \
addi x31, x31, -256; \
addi x1, x1, 512; \
addi x1, x1, -512; \
addi x2, x2, 512; \
addi x2, x2, -512; \
addi x3, x3, 512; \
addi x3, x3, -512; \
addi x4, x4, 512; \
addi x4, x4, -512; \
addi x5, x5, 512; \
addi x5, x5, -512; \
addi x6, x6, 512; \
addi x6, x6, -512; \
addi x7, x7, 512; \
addi x7, x7, -512; \
addi x8, x8, 512; \
addi x8, x8, -512; \
addi x9, x9, 512; \
addi x9, x9, -512; \
addi x10, x10, 512; \
addi x10, x10, -512; \
addi x11, x11, 512; \
addi x11, x11, -512; \
addi x12, x12, 512; \
addi x12, x12, -512; \
addi x13, x13, 512; \
addi x13, x13, -512; \
addi x14, x14, 512; \
addi x14, x14, -512; \
addi x15, x15, 512; \
addi x15, x15, -512; \
addi x16, x16, 512; \
addi x16, x16, -512; \
addi x17, x17, 512; \
addi x17, x17, -512; \
addi x18, x18, 512; \
addi x18, x18, -512; \
addi x19, x19, 512; \
addi x19, x19, -512; \
addi x20, x20, 512; \
addi x20, x20, -512; \
addi x21, x21, 512; \
addi x21, x21, -512; \
addi x22, x22, 512; \
addi x22, x22, -512; \
addi x23, x23, 512; \
addi x23, x23, -512; \
addi x24, x24, 512; \
addi x24, x24, -512; \
addi x25, x25, 512; \
addi x25, x25, -512; \
addi x26, x26, 512; \
addi x26, x26, -512; \
addi x27, x27, 512; \
addi x27, x27, -512; \
addi x28, x28, 512; \
addi x28, x28, -512; \
addi x29, x29, 512; \
addi x29, x29, -512; \
addi x30, x30, 512; \
addi x30, x30, -512; \
addi x31, x31, 512; \
addi x31, x31, -512; \
addi x1, x1, 1024; \
addi x1, x1, -1024; \
addi x2, x2, 1024; \
addi x2, x2, -1024; \
addi x3, x3, 1024; \
addi x3, x3, -1024; \
addi x4, x4, 1024; \
addi x4, x4, -1024; \
addi x5, x5, 1024; \
addi x5, x5, -1024; \
addi x6, x6, 1024; \
addi x6, x6, -1024; \
addi x7, x7, 1024; \
addi x7, x7, -1024; \
addi x8, x8, 1024; \
addi x8, x8, -1024; \
addi x9, x9, 1024; \
addi x9, x9, -1024; \
addi x10, x10, 1024; \
addi x10, x10, -1024; \
addi x11, x11, 1024; \
addi x11, x11, -1024; \
addi x12, x12, 1024; \
addi x12, x12, -1024; \
addi x13, x13, 1024; \
addi x13, x13, -1024; \
addi x14, x14, 1024; \
addi x14, x14, -1024; \
addi x15, x15, 1024; \
addi x15, x15, -1024; \
addi x16, x16, 1024; \
addi x16, x16, -1024; \
addi x17, x17, 1024; \
addi x17, x17, -1024; \
addi x18, x18, 1024; \
addi x18, x18, -1024; \
addi x19, x19, 1024; \
addi x19, x19, -1024; \
addi x20, x20, 1024; \
addi x20, x20, -1024; \
addi x21, x21, 1024; \
addi x21, x21, -1024; \
addi x22, x22, 1024; \
addi x22, x22, -1024; \
addi x23, x23, 1024; \
addi x23, x23, -1024; \
addi x24, x24, 1024; \
addi x24, x24, -1024; \
addi x25, x25, 1024; \
addi x25, x25, -1024; \
addi x26, x26, 1024; \
addi x26, x26, -1024; \
addi x27, x27, 1024; \
addi x27, x27, -1024; \
addi x28, x28, 1024; \
addi x28, x28, -1024; \
addi x29, x29, 1024; \
addi x29, x29, -1024; \
addi x30, x30, 1024; \
addi x30, x30, -1024; \
addi x31, x31, 1024; \
addi x31, x31, -1024; \
bne x1, x0, fail; \
bne x2, x0, fail; \
bne x3, x0, fail; \
bne x4, x0, fail; \
bne x5, x0, fail; \
bne x6, x0, fail; \
bne x7, x0, fail; \
bne x8, x0, fail; \
bne x9, x0, fail; \
bne x10, x0, fail; \
bne x11, x0, fail; \
bne x12, x0, fail; \
bne x13, x0, fail; \
bne x14, x0, fail; \
bne x15, x0, fail; \
bne x16, x0, fail; \
bne x17, x0, fail; \
bne x18, x0, fail; \
bne x19, x0, fail; \
bne x20, x0, fail; \
bne x21, x0, fail; \
bne x22, x0, fail; \
bne x23, x0, fail; \
bne x24, x0, fail; \
bne x25, x0, fail; \
bne x26, x0, fail; \
bne x27, x0, fail; \
bne x28, x0, fail; \
bne x29, x0, fail; \
bne x30, x0, fail; \
bne x31, x0, fail;

#define code_block_8x \ 
  code_block \
  code_block \
  code_block \
  code_block \
  code_block \
  code_block \
  code_block \
  code_block

#define code_block_64x \ 
  code_block_8x \
  code_block_8x \
  code_block_8x \
  code_block_8x \
  code_block_8x \
  code_block_8x \
  code_block_8x \
  code_block_8x

#define code_block_512x \ 
  code_block_64x \
  code_block_64x \
  code_block_64x \
  code_block_64x \
  code_block_64x \
  code_block_64x \
  code_block_64x \
  code_block_64x

code_block_64x
code_block_64x
code_block_64x
code_block_64x
code_block_64x
code_block_8x
code_block_8x
code_block_8x
code_block_8x

pass:
  bsg_asm_finish(IO_X_INDEX, 0)
pass_loop:
  j pass_loop
fail:
  bsg_asm_fail(IO_X_INDEX, 0)
fail_loop:
  j fail_loop
