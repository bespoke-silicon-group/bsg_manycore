// This kernel performs saxpy to demonstrate how the placement of
// bsg_attr_remote AND bsg_attr_noalias affects code generation.

// For a demonstration of each annotation independently see the
// remote, and noalias directories.

// NOTE: 

// bsg_attr_remote is currently NOT SUPPORTED in C++ WITH GCC. This
// file is written in C to demonstrate concepts until a solution is
// developed.


// Our goal is to optimize saxpy (Scalar * X Plus Y) by unrolling it
// by a factor of 4 to increase performance. Performance gains can be
// attributed to two effects: 

// 1) Increasing the distance between load and use instructions to
// hide DRAM latency, by informing the compiler about the latency of
// (remote) loads

// 2) Reducing loop control overhead.

// In this set of examples we will use the bsg_attr_remote annotation 
// Our goal is to optimize vector add, and unroll it by a factor of 4
// to improve performance by 1) Issuing blocks of loads to hide latency
// 2) Reduce loop control overhead.

// Simply unrolling the loop will not achieve either 1) or 2)
// above. The compiler is not allowed to reorder loads and stores
// unless it can absolutely determine that the loads and stores are
// independent -- i.e. they do not alias. Furthermore, it will not
// have accurate latency estimates for load/store instructions.

// To solve the aliasing issue, use bsg_attr_remote.In general the
// compiler cannot infer alias information from pointers just by
// analyzing the code. The annotation bsg_attr_noalias is required and
// is similar to the behavior of __restrict.

// Even if the code is decorated with bsg_attr_noalias, the code will
// still may not be optimal. GCC assumes a normal processor hierarchy
// with a 1-2 cycle L1 cache. This means that load instructions will
// be quickly followed by dependent instructions, and dependent
// instructions will be quickly followed by subsequent dependent
// instructions, such as store. This works for data in scratchpad, but
// when data is located in DRAM, or cache, the processor will stall on
// dependent instructions will the data is in flight because the
// compiler did not reorder instructions to hide data access
// latency. Therefore, is critical to give the compiler accurate
// information about the expected latency to access data.

// To signal that a memory location has high latency, annotate
// pointers with bsg_attr_remote.


#include <bsg_manycore.h>

void saxpy(float  *A, float  *B, float *C, float alpha) {
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}

/*
Compiler: LLVM (GCC below)
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: The compiler does not aggregate blocks of load instructions
and the load-use distance is small. The compiler does not have a
correct cost model for the data in DRAM.

NOTE: LLVM does not insert Fused-Multiply-Add instructions. A solution is being found.

void saxpy(float  *  A, float  *  B, float *C, float alpha) {
 250:   00000693                li      x13,0
        float s = 0;
        bsg_unroll(4)
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
 2c4:   fb0690e3                bne     x13,x16,264 <_Z7saxpyPfS_S_f+0x14>
        }
}
 2c8:   00008067                ret

Compiler: GCC
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: The compiler does not aggregate blocks of load instructions
and the load-use distance is small. The compiler does not have a
correct cost model for the data in DRAM.

Unlike LLVM, gcc inserts Fused-Multiply-Add (fmadd.s) instructions.

void saxpy(float  *A, float  *B, float *C, float alpha) {
 250:   00000793                li      x15,0
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < 16; ++i) {
 254:   04000313                li      x6,64
                C[i] = alpha * A[i] + B[i];
 258:   00f506b3                add     x13,x10,x15
 25c:   00f58733                add     x14,x11,x15
 260:   0006a787                flw     f15,0(x13)
 264:   00072707                flw     f14,0(x14)
 268:   00478293                addi    x5,x15,4
 26c:   00f608b3                add     x17,x12,x15
 270:   70a7f043                fmadd.s f0,f15,f10,f14
 274:   00550833                add     x16,x10,x5
 278:   005583b3                add     x7,x11,x5
 27c:   0008a027                fsw     f0,0(x17)
 280:   00082087                flw     f1,0(x16)
 284:   0003a107                flw     f2,0(x7)
 288:   00878e13                addi    x28,x15,8
 28c:   00560eb3                add     x29,x12,x5
 290:   10a0f1c3                fmadd.s f3,f1,f10,f2
 294:   01c50f33                add     x30,x10,x28
 298:   01c58fb3                add     x31,x11,x28
 29c:   003ea027                fsw     f3,0(x29)
 2a0:   000f2207                flw     f4,0(x30)
 2a4:   000fa287                flw     f5,0(x31)
 2a8:   00c78713                addi    x14,x15,12
 2ac:   01c606b3                add     x13,x12,x28
 2b0:   28a27343                fmadd.s f6,f4,f10,f5
 2b4:   00e502b3                add     x5,x10,x14
 2b8:   00e588b3                add     x17,x11,x14
 2bc:   0066a027                fsw     f6,0(x13)
 2c0:   0002a387                flw     f7,0(x5)
 2c4:   0008a587                flw     f11,0(x17)
 2c8:   00e60833                add     x16,x12,x14
 2cc:   01078793                addi    x15,x15,16
 2d0:   58a3f643                fmadd.s f12,f7,f10,f11
 2d4:   00c82027                fsw     f12,0(x16)
        for(int i = 0;  i < 16; ++i) {
 2d8:   f86790e3                bne     x15,x6,258 <saxpy+0x8>
        }
}
 2dc:   00008067                ret

*/



void saxpy_remote_restrict(float bsg_attr_remote * __restrict A, float bsg_attr_remote * __restrict B, float bsg_attr_remote * __restrict C, float alpha) {
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}

/*
Compiler: LLVM (GCC below)
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: The aggregate blocks of load instructions by reordering past
store instructions (noalias), and the load-use distance is large (remote).

Note: LLVM doesn't insert fmadd instructions at the moment.

void saxpy_remote_restrict(float bsg_attr_remote * __restrict A, float bsg_attr_remote * __restrict B, float bsg_attr_remote * __restrict C, float alpha) {
 2cc:   00000693                li      x13,0
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < 16; ++i) {
 2d0:   00860613                addi    x12,x12,8
 2d4:   00c58593                addi    x11,x11,12
 2d8:   00c50513                addi    x10,x10,12
 2dc:   04000813                li      x16,64
                C[i] = alpha * A[i] + B[i];
 2e0:   00d507b3                add     x15,x10,x13
 2e4:   ff47a007                flw     f0,-12(x15)
 2e8:   ff87a087                flw     f1,-8(x15)
 2ec:   00d58733                add     x14,x11,x13
 2f0:   ffc7a107                flw     f2,-4(x15)
 2f4:   ff472187                flw     f3,-12(x14)
 2f8:   ff872207                flw     f4,-8(x14)
 2fc:   0007a287                flw     f5,0(x15)
 300:   ffc72307                flw     f6,-4(x14)
 304:   00072387                flw     f7,0(x14)
 308:   10a07053                fmul.s  f0,f0,f10
 30c:   10a0f0d3                fmul.s  f1,f1,f10
 310:   10a17153                fmul.s  f2,f2,f10
 314:   00307053                fadd.s  f0,f0,f3
 318:   0040f0d3                fadd.s  f1,f1,f4
 31c:   10a2f1d3                fmul.s  f3,f5,f10
 320:   00617153                fadd.s  f2,f2,f6
 324:   00d60733                add     x14,x12,x13
 328:   fe072c27                fsw     f0,-8(x14)
 32c:   0071f053                fadd.s  f0,f3,f7
 330:   fe172e27                fsw     f1,-4(x14)
 334:   00272027                fsw     f2,0(x14)
        for(int i = 0;  i < 16; ++i) {
 338:   01068693                addi    x13,x13,16
                C[i] = alpha * A[i] + B[i];
 33c:   00072227                fsw     f0,4(x14)
        for(int i = 0;  i < 16; ++i) {
 340:   fb0690e3                bne     x13,x16,2e0 <saxpy_remote_restrict+0x14>
        }
}
 344:   00008067                ret

Compiler: GCC
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: The aggregate blocks of load instructions by reordering past
store instructions (noalias), and the load-use distance is large (remote).


void saxpy_remote_restrict(float bsg_attr_remote * __restrict A, float bsg_attr_remote * __restrict B, float bsg_attr_remote * __restrict C, float alpha) {
        float s = 0;
        bsg_unroll(4)
        for(int i = 0;  i < 16; ++i) {
 2e0:   04050793                addi    x15,x10,64
                C[i] = alpha * A[i] + B[i];
 2e4:   00052607                flw     f12,0(x10)
 2e8:   0005a107                flw     f2,0(x11)
 2ec:   00452687                flw     f13,4(x10)
 2f0:   0045a087                flw     f1,4(x11)
 2f4:   00852707                flw     f14,8(x10)
 2f8:   0085a007                flw     f0,8(x11)
 2fc:   00c52787                flw     f15,12(x10)
 300:   00c5a587                flw     f11,12(x11)
 304:   10a671c3                fmadd.s f3,f12,f10,f2
 308:   08a6f243                fmadd.s f4,f13,f10,f1
 30c:   00a772c3                fmadd.s f5,f14,f10,f0
 310:   58a7f343                fmadd.s f6,f15,f10,f11
 314:   00362027                fsw     f3,0(x12)
 318:   00462227                fsw     f4,4(x12)
 31c:   00562427                fsw     f5,8(x12)
 320:   00662627                fsw     f6,12(x12)
        for(int i = 0;  i < 16; ++i) {
 324:   01050513                addi    x10,x10,16
 328:   01058593                addi    x11,x11,16
 32c:   01060613                addi    x12,x12,16
 330:   faf51ae3                bne     x10,x15,2e4 <saxpy_remote_restrict+0x4>
        }
}
 334:   00008067                ret



*/
