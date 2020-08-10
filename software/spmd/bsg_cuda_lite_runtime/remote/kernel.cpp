// This kernel performs saxpy to demonstrate how the placement of
// __remote affects code generation.

// NOTE: 

// __remote is NOT SUPPORTED in C++ WITH GCC.

// Our goal is to optimize saxpy (Scalar * X Plus Y) by unrolling it
// by a factor of 4 to increase performance. Performance gains can be
// attributed to two effects: 

// 1) Increasing the distance between load and use instructions to
// hide DRAM latency, by informing the compiler about the latency of
// (remote) loads

// 2) Reduce loop control overhead.

// In this set of examples we will use the __remote annotation 
// Our goal is to optimize vector add, and unroll it by a factor of 4
// to improve performance by 1) Issuing blocks of loads to hide latency
// 2) Reduce loop control overhead.

// Using __restrict is one of TWO critical steps to utilizing
// non-blocking loads effectively in the manycore architecture.

// For the other critical step see kernel.cpp in the restrict
// directory. 

// For a synthesis of the two, see remote+restrict

#include <bsg_manycore.h>

void vec_add(float  *A, float  *B, float *C, float alpha) {
        float s = 0;
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}

/*
Compiler: LLVM
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: The compiler does not aggregate blocks of load instructions
and the load-use distance is small. The compiler does not have a
correct cost model for the data in DRAM.

void vec_add(float  *  A, float  *  B, float *C, float alpha) {
 250:   00000693                li      x13,0
        float s = 0;
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
 254:   00860893                addi    x17,x12,8
 258:   00c58593                addi    x11,x11,12
 25c:   00c50513                addi    x10,x10,12
 260:   04000813                li      x16,64
                C[i] = alpha * A[i] + B[i];
 264:   00d507b3                add     x15,x10,x13
 268:   ff47a007                flw     f0,-12(x15)
 26c:   10a07053                fmul.s  f0,f0,f10
 270:   00d58733                add     x14,x11,x13
 274:   ff472087                flw     f1,-12(x14)
 278:   00107053                fadd.s  f0,f0,f1
 27c:   00d88633                add     x12,x17,x13
 280:   fe062c27                fsw     f0,-8(x12)
 284:   ff87a007                flw     f0,-8(x15)
 288:   10a07053                fmul.s  f0,f0,f10
 28c:   ff872087                flw     f1,-8(x14)
 290:   00107053                fadd.s  f0,f0,f1
 294:   fe062e27                fsw     f0,-4(x12)
 298:   ffc7a007                flw     f0,-4(x15)
 29c:   10a07053                fmul.s  f0,f0,f10
 2a0:   ffc72087                flw     f1,-4(x14)
 2a4:   00107053                fadd.s  f0,f0,f1
 2a8:   00062027                fsw     f0,0(x12)
 2ac:   0007a007                flw     f0,0(x15)
 2b0:   10a07053                fmul.s  f0,f0,f10
 2b4:   00072087                flw     f1,0(x14)
 2b8:   00107053                fadd.s  f0,f0,f1
        for(int i = 0;  i < 16; ++i) {
 2bc:   01068693                addi    x13,x13,16
                C[i] = alpha * A[i] + B[i];
 2c0:   00062227                fsw     f0,4(x12)
        for(int i = 0;  i < 16; ++i) {
 2c4:   fb0690e3                bne     x13,x16,264 <_Z7vec_addPfS_S_f+0x14>
        }
}
 2c8:   00008067                ret
*/


void vec_add_remote(float __remote * A, float __remote * B, float __remote * C, float alpha) {
        float s = 0;
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}

/*
Compiler: LLVM
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: The aggregates blocks of load instructions far from their use
sitebut cannot reorder them to create larger blocks.

void vec_add_remote(float __remote * A, float __remote * B, float __remote * C, float alpha) {
 2cc:   00000693                li      x13,0
        float s = 0;
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
 2d0:   00860893                addi    x17,x12,8
 2d4:   00c58593                addi    x11,x11,12
 2d8:   00c50513                addi    x10,x10,12
 2dc:   04000813                li      x16,64
                C[i] = alpha * A[i] + B[i];
 2e0:   00d507b3                add     x15,x10,x13
 2e4:   ff47a007                flw     f0,-12(x15)
 2e8:   00d58733                add     x14,x11,x13
 2ec:   ff472087                flw     f1,-12(x14)
 2f0:   10a07053                fmul.s  f0,f0,f10
 2f4:   00107053                fadd.s  f0,f0,f1
 2f8:   00d88633                add     x12,x17,x13
 2fc:   fe062c27                fsw     f0,-8(x12)
 300:   ff87a007                flw     f0,-8(x15)
 304:   ff872087                flw     f1,-8(x14)
 308:   10a07053                fmul.s  f0,f0,f10
 30c:   00107053                fadd.s  f0,f0,f1
 310:   fe062e27                fsw     f0,-4(x12)
 314:   ffc7a007                flw     f0,-4(x15)
 318:   ffc72087                flw     f1,-4(x14)
 31c:   10a07053                fmul.s  f0,f0,f10
 320:   00107053                fadd.s  f0,f0,f1
 324:   00062027                fsw     f0,0(x12)
 328:   0007a007                flw     f0,0(x15)
 32c:   00072087                flw     f1,0(x14)
 330:   10a07053                fmul.s  f0,f0,f10
 334:   00107053                fadd.s  f0,f0,f1
        for(int i = 0;  i < 16; ++i) {
 338:   01068693                addi    x13,x13,16
                C[i] = alpha * A[i] + B[i];
 33c:   00062227                fsw     f0,4(x12)
        for(int i = 0;  i < 16; ++i) {
 340:   fb0690e3                bne     x13,x16,2e0 <_Z14vec_add_remotePU3AS1fS0_S0_f+0x14>
        }
}
 344:   00008067                ret
*/


void vec_add_remote_restrict(float __remote * __restrict A, float __remote * __restrict B, float __remote * __restrict C, float alpha) {
        float s = 0;
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] += alpha * A[i] + B[i];
        }
}


void vec_add_remote_restrict_const(float __remote const * __restrict const A, float __remote const * __restrict const B, float __remote * __restrict const C, float alpha) {
        float s = 0;
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] += alpha * A[i] + B[i];
        }
}
