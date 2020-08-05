// This kernel performs saxpy to demonstrate how the placement of
// __restrict affects code generation.

// NOTE: 

// __restrict is NOT FULLY SUPPORTED IN LLVM. It works for 1D array
// accesses, but your mileage may vary with anything more complex.



// Our goal is to optimize saxpy (Scalar * X Plus Y) by unrolling it
// by a factor of 4 to increase performance. Performance gains can be
// attributed to two effects: 

// 1) Increasing the distance between load and use instructions to
// hide DRAM latency 

// 2) Reduce loop control overhead.

// In this example we will use the restrict type qualifier
// (https://en.cppreference.com/w/c/language/restrict) on pointers to
// indicate that unique pointer declarations represent non-overlapping
// regions of memory (i.e. they do not alias).

// restrict allows the compiler to reorder loads and stores to unique
// pointer declarations because stores to a restricted pointer do not
// modify the data of restricted pointer declarations.

// Reordering means loads can be moved ahead of the stores of a
// previous iteration to increase the instruction distance between
// load and use.

// Using __restrict is one of TWO critical steps to utilizing
// non-blocking loads effectively in the manycore architecture.

// For the second critical step see kernel.cpp in the remote
// directory.

// For a synthesis of the two, see remote+restrict

#include <bsg_manycore.h>

extern "C"
void saxpy(float  *  A, float  *  B, float *C, float alpha) {
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}

/*
Compiler: LLVM
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: The compiler cannot guarantee that stores to C do not affect A
and B, so loop iterations are not overlapped

void saxpy(float  *  A, float  *  B, float *C, float alpha) {
 250:	00000693          	li	x13,0
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
 254:	00860893          	addi	x17,x12,8
 258:	00c58593          	addi	x11,x11,12
 25c:	00c50513          	addi	x10,x10,12
 260:	04000813          	li	x16,64
                C[i] = alpha * A[i] + B[i];
 264:	00d507b3          	add	x15,x10,x13
 268:	ff47a007          	flw	f0,-12(x15) // Start of Unrolled Iteration 0
 26c:	10a07053          	fmul.s	f0,f0,f10
 270:	00d58733          	add	x14,x11,x13
 274:	ff472087          	flw	f1,-12(x14)
 278:	00107053          	fadd.s	f0,f0,f1
 27c:	00d88633          	add	x12,x17,x13
 280:	fe062c27          	fsw	f0,-8(x12) // End of Iteration 0
 284:	ff87a007          	flw	f0,-8(x15) // Start of Unrolled Iteration 1
 288:	10a07053          	fmul.s	f0,f0,f10
 28c:	ff872087          	flw	f1,-8(x14)
 290:	00107053          	fadd.s	f0,f0,f1
 294:	fe062e27          	fsw	f0,-4(x12) // End of Iteration 1
 298:	ffc7a007          	flw	f0,-4(x15) // Start of Unrolled Iteration 2
 29c:	10a07053          	fmul.s	f0,f0,f10
 2a0:	ffc72087          	flw	f1,-4(x14)
 2a4:	00107053          	fadd.s	f0,f0,f1
 2a8:	00062027          	fsw	f0,0(x12) // End of Iteration 2
 2ac:	0007a007          	flw	f0,0(x15) // Start of Unrolled Iteration 3
 2b0:	10a07053          	fmul.s	f0,f0,f10
 2b4:	00072087          	flw	f1,0(x14)
 2b8:	00107053          	fadd.s	f0,f0,f1
        for(int i = 0;  i < 16; ++i) {
 2bc:	01068693          	addi	x13,x13,16
                C[i] = alpha * A[i] + B[i];
 2c0:	00062227          	fsw	f0,4(x12) // End of Iteration 3
        for(int i = 0;  i < 16; ++i) {
 2c4:	fb0690e3          	bne	x13,x16,264 <_Z7saxpyPfS_S_f+0x14>
        }
}
 2c8:	00008067          	ret
*/

extern "C"
void saxpy_const(float const * const A, float const * const B, float * const C, float alpha) {
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}

/*
Compiler: LLVM
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: This produces the same assembly as saxpy

void saxpy_const(float const * const A, float const * const B, float * const C, float alpha) {
 2cc:	00000693          	li	x13,0
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
 2d0:	00860893          	addi	x17,x12,8
 2d4:	00c58593          	addi	x11,x11,12
 2d8:	00c50513          	addi	x10,x10,12
 2dc:	04000813          	li	x16,64
                C[i] = alpha * A[i] + B[i];
 2e0:	00d507b3          	add	x15,x10,x13
 2e4:	ff47a007          	flw	f0,-12(x15) // Start of Iteration 0
 2e8:	10a07053          	fmul.s	f0,f0,f10
 2ec:	00d58733          	add	x14,x11,x13
 2f0:	ff472087          	flw	f1,-12(x14)
 2f4:	00107053          	fadd.s	f0,f0,f1
 2f8:	00d88633          	add	x12,x17,x13
 2fc:	fe062c27          	fsw	f0,-8(x12) // End of Iteration 0
 300:	ff87a007          	flw	f0,-8(x15) // Start of Iteration 1
 304:	10a07053          	fmul.s	f0,f0,f10
 308:	ff872087          	flw	f1,-8(x14)
 30c:	00107053          	fadd.s	f0,f0,f1
 310:	fe062e27          	fsw	f0,-4(x12) // End of Iteration 1
 314:	ffc7a007          	flw	f0,-4(x15) // Start of Iteration 2
 318:	10a07053          	fmul.s	f0,f0,f10
 31c:	ffc72087          	flw	f1,-4(x14)
 320:	00107053          	fadd.s	f0,f0,f1
 324:	00062027          	fsw	f0,0(x12) // End of Iteration 2
 328:	0007a007          	flw	f0,0(x15) // Start of Iteration 3
 32c:	10a07053          	fmul.s	f0,f0,f10
 330:	00072087          	flw	f1,0(x14)
 334:	00107053          	fadd.s	f0,f0,f1
        for(int i = 0;  i < 16; ++i) {
 338:	01068693          	addi	x13,x13,16
                C[i] = alpha * A[i] + B[i];
 33c:	00062227          	fsw	f0,4(x12) // End of Iteration 3
        for(int i = 0;  i < 16; ++i) {
 340:	fb0690e3          	bne	x13,x16,2e0 <saxpy_const+0x14>
        }
}
 344:	00008067          	ret
*/

extern "C"
void saxpy_restrict(float * __restrict A, float * __restrict B, float * __restrict C, float alpha) {
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[i] + B[i];
        }
}

/*
Compiler: LLVM
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: The compiler can now overlap iterations, because the pointers do not alias

void saxpy_restrict(float * __restrict A, float * __restrict B, float * __restrict C, float alpha) {
 348:	00000693          	li	x13,0
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
 34c:	00860893          	addi	x17,x12,8
 350:	00c58593          	addi	x11,x11,12
 354:	00c50513          	addi	x10,x10,12
 358:	04000813          	li	x16,64
                C[i] = alpha * A[i] + B[i];
 35c:	00d507b3          	add	x15,x10,x13
 360:	ff47a007          	flw	f0,-12(x15) // Start of Iteration 0
 364:	10a07053          	fmul.s	f0,f0,f10   
 368:	00d58733          	add	x14,x11,x13
 36c:	ff472087          	flw	f1,-12(x14) 
 370:	ff87a107          	flw	f2,-8(x15) // Start of Iteration 1
 374:	00107053          	fadd.s	f0,f0,f1
 378:	10a170d3          	fmul.s	f1,f2,f10
 37c:	00d88633          	add	x12,x17,x13
 380:	ff872107          	flw	f2,-8(x14) 
 384:	ffc7a187          	flw	f3,-4(x15) // Start of Iteration 2
 388:	0020f0d3          	fadd.s	f1,f1,f2
 38c:	10a1f153          	fmul.s	f2,f3,f10
 390:	0007a187          	flw	f3,0(x15)
 394:	ffc72207          	flw	f4,-4(x14) // Start of Iteration 3
 398:	10a1f1d3          	fmul.s	f3,f3,f10
 39c:	00417153          	fadd.s	f2,f2,f4
 3a0:	00072207          	flw	f4,0(x14)
 3a4:	fe062c27          	fsw	f0,-8(x12) // End of Iteration 0
 3a8:	0041f053          	fadd.s	f0,f3,f4   
 3ac:	fe162e27          	fsw	f1,-4(x12) // End of Iteration 1
 3b0:	00262027          	fsw	f2,0(x12)  // End of Iteration 2
        for(int i = 0;  i < 16; ++i) {
 3b4:	01068693          	addi	x13,x13,16
                C[i] = alpha * A[i] + B[i];
 3b8:	00062227          	fsw	f0,4(x12) // End of Iteration 3
        for(int i = 0;  i < 16; ++i) {
 3bc:	fb0690e3          	bne	x13,x16,35c <saxpy_restrict+0x14>
        }
}
 3c0:	00008067          	ret
*/


// Use caution when applying __restrict to multi-dimensional
// arrays. The code generation can vary between compiler. In this
// example LLVM produces worse code than GCC.

// This is a known issue in LLVM with a patch under review (as of 8/20):
// Google: restrict support in llvm
// LLVM Patch: https://reviews.llvm.org/D69542

// In this example, A is a 2x16 array. We will perform saxpy using
// A[0] as x and A[1] as y.

// In saxpy_restrict_A, below, __restrict is only applied to the first
// dimension of A. The compiler still believes that writes to C affect
// data in the second dimension of A and cannot reorder instructions.

// In saxpy_A_restrict, below, __restrict is only applied to the
// second dimension of A. similar to saxpy_restrict_A, the compiler
// sill believes that writes to C can affect the pointer in the first
// dimension of A and cannot reorder instructions

// __restrict must be applied to each pointer to be inferred
// correctly. 

extern "C"
void saxpy_restrict_A(float * __restrict * A, float * __restrict C, float alpha) {
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[0][i] + A[1][i];
        }
}

extern "C"
void saxpy_A_restrict(float ** __restrict A, float * __restrict C, float alpha) {
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[0][i] + A[1][i];
        }
}

extern "C"
void saxpy_restrict_restrict(float * __restrict * __restrict A, float * __restrict C, float alpha) {
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[0][i] + A[1][i];
        }
}


/*

Compiler: LLVM
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result (saxpy_restrict_A): The compiler cannot guarantee that stores
to C do not affect the second dimension of A, so loop iterations are
not overlapped

Result (saxpy_A_restrict): The compiler cannot guarantee that stores
to C do not affect the first dimension of A, so loop iterations are
not overlapped

Result (saxpy_restrict_restrict): In LLVM, the compiler does not infer
correct aliasing. GCC does (see below)

void saxpy_restrict_A(float * __restrict * A, float * __restrict C, float alpha) {
 3c4:	00000613          	li	x12,0
 3c8:	00052683          	lw	x13,0(x10)
 3cc:	00452703          	lw	x14,4(x10)
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
 3d0:	00858893          	addi	x17,x11,8
 3d4:	00c70593          	addi	x11,x14,12
 3d8:	00c68693          	addi	x13,x13,12
 3dc:	04000813          	li	x16,64
                C[i] = alpha * A[0][i] + A[1][i];
 3e0:	00c687b3          	add	x15,x13,x12
 3e4:	ff47a007          	flw	f0,-12(x15) // Start of Iteration 0
 3e8:	10a07053          	fmul.s	f0,f0,f10
 3ec:	00c58733          	add	x14,x11,x12
 3f0:	ff472087          	flw	f1,-12(x14)
 3f4:	0000f053          	fadd.s	f0,f1,f0
 3f8:	00c88533          	add	x10,x17,x12
 3fc:	fe052c27          	fsw	f0,-8(x10) // End of Iteration 0
 400:	ff87a007          	flw	f0,-8(x15) // Start of Iteration 1
 404:	10a07053          	fmul.s	f0,f0,f10
 408:	ff872087          	flw	f1,-8(x14)
 40c:	0000f053          	fadd.s	f0,f1,f0
 410:	fe052e27          	fsw	f0,-4(x10) // End of Iteration 1
 414:	ffc7a007          	flw	f0,-4(x15) // Start of Iteration 2
 418:	10a07053          	fmul.s	f0,f0,f10
 41c:	ffc72087          	flw	f1,-4(x14)
 420:	0000f053          	fadd.s	f0,f1,f0
 424:	00052027          	fsw	f0,0(x10) // End of Iteration 2
 428:	0007a007          	flw	f0,0(x15) // Start of Iteration 3
 42c:	10a07053          	fmul.s	f0,f0,f10
 430:	00072087          	flw	f1,0(x14) 
 434:	0000f053          	fadd.s	f0,f1,f0
        for(int i = 0;  i < 16; ++i) {
 438:	01060613          	addi	x12,x12,16
                C[i] = alpha * A[0][i] + A[1][i];
 43c:	00052227          	fsw	f0,4(x10) // End of Iteration 3
        for(int i = 0;  i < 16; ++i) {
 440:	fb0610e3          	bne	x12,x16,3e0 <saxpy_restrict_A+0x1c>
        }
}
 444:	00008067          	ret

void saxpy_A_restrict(float ** __restrict A, float * __restrict C, float alpha) {
 448:	00000613          	li	x12,0
 44c:	00052683          	lw	x13,0(x10)
 450:	00452703          	lw	x14,4(x10)
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
 454:	00858893          	addi	x17,x11,8
 458:	00c70593          	addi	x11,x14,12
 45c:	00c68693          	addi	x13,x13,12
 460:	04000813          	li	x16,64
                C[i] = alpha * A[0][i] + A[1][i];
 464:	00c687b3          	add	x15,x13,x12
 468:	ff47a007          	flw	f0,-12(x15) // Start of Iteration 0
 46c:	10a07053          	fmul.s	f0,f0,f10
 470:	00c58733          	add	x14,x11,x12
 474:	ff472087          	flw	f1,-12(x14)
 478:	0000f053          	fadd.s	f0,f1,f0
 47c:	00c88533          	add	x10,x17,x12
 480:	fe052c27          	fsw	f0,-8(x10) // End of Iteration 0
 484:	ff87a007          	flw	f0,-8(x15) // Start of Iteration 1
 488:	10a07053          	fmul.s	f0,f0,f10
 48c:	ff872087          	flw	f1,-8(x14)
 490:	0000f053          	fadd.s	f0,f1,f0
 494:	fe052e27          	fsw	f0,-4(x10) // End of Iteration 1
 498:	ffc7a007          	flw	f0,-4(x15) // Start of Iteration 2
 49c:	10a07053          	fmul.s	f0,f0,f10
 4a0:	ffc72087          	flw	f1,-4(x14)
 4a4:	0000f053          	fadd.s	f0,f1,f0
 4a8:	00052027          	fsw	f0,0(x10) // End of Iteration 2
 4ac:	0007a007          	flw	f0,0(x15) // Start of Iteration 3
 4b0:	10a07053          	fmul.s	f0,f0,f10
 4b4:	00072087          	flw	f1,0(x14)
 4b8:	0000f053          	fadd.s	f0,f1,f0
        for(int i = 0;  i < 16; ++i) {
 4bc:	01060613          	addi	x12,x12,16
                C[i] = alpha * A[0][i] + A[1][i];
 4c0:	00052227          	fsw	f0,4(x10) // End of Iteration 3
        for(int i = 0;  i < 16; ++i) {
 4c4:	fb0610e3          	bne	x12,x16,464 <saxpy_A_restrict+0x1c>
        }
}
 4c8:	00008067          	ret
*/

/*


void saxpy_restrict_restrict(float const * __restrict * __restrict A, float * __restrict C, float alpha) {
 4cc:	00000613          	li	x12,0
 4d0:	00052683          	lw	x13,0(x10)
 4d4:	00452703          	lw	x14,4(x10)
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
 4d8:	00858893          	addi	x17,x11,8
 4dc:	00c70593          	addi	x11,x14,12
 4e0:	00c68693          	addi	x13,x13,12
 4e4:	04000813          	li	x16,64
                C[i] = alpha * A[0][i] + A[1][i];
 4e8:	00c687b3          	add	x15,x13,x12
 4ec:	ff47a007          	flw	f0,-12(x15) // Start of Iteration 0
 4f0:	10a07053          	fmul.s	f0,f0,f10
 4f4:	00c58733          	add	x14,x11,x12
 4f8:	ff472087          	flw	f1,-12(x14)
 4fc:	0000f053          	fadd.s	f0,f1,f0
 500:	00c88533          	add	x10,x17,x12
 504:	fe052c27          	fsw	f0,-8(x10) // End of Iteration 0
 508:	ff87a007          	flw	f0,-8(x15) // Start of Iteration 1
 50c:	10a07053          	fmul.s	f0,f0,f10
 510:	ff872087          	flw	f1,-8(x14)
 514:	0000f053          	fadd.s	f0,f1,f0
 518:	fe052e27          	fsw	f0,-4(x10) // End of Iteration 1
 51c:	ffc7a007          	flw	f0,-4(x15) // Start of Iteration 2
 520:	10a07053          	fmul.s	f0,f0,f10
 524:	ffc72087          	flw	f1,-4(x14)
 528:	0000f053          	fadd.s	f0,f1,f0
 52c:	00052027          	fsw	f0,0(x10) // End of Iteration 2
 530:	0007a007          	flw	f0,0(x15) // Start of Iteration 3
 534:	10a07053          	fmul.s	f0,f0,f10
 538:	00072087          	flw	f1,0(x14)
 53c:	0000f053          	fadd.s	f0,f1,f0
        for(int i = 0;  i < 16; ++i) {
 540:	01060613          	addi	x12,x12,16
                C[i] = alpha * A[0][i] + A[1][i];
 544:	00052227          	fsw	f0,4(x10) // End of Iteration 3
        for(int i = 0;  i < 16; ++i) {
 548:	fb0610e3          	bne	x12,x16,4e8 <saxpy_restrict_restrict+0x1c>
        }
}
 54c:	00008067          	ret

Compiler: GCC

void saxpy_restrict_restrict(float * __restrict * __restrict A, float * __restrict C, float alpha) {
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[0][i] + A[1][i];
 530:	00052803          	lw	x16,0(x10)
 534:	00452503          	lw	x10,4(x10)
 538:	00000793          	li	x15,0
        for(int i = 0;  i < 16; ++i) {
 53c:	04000e13          	li	x28,64
                C[i] = alpha * A[0][i] + A[1][i];
 540:	00478613          	addi	x12,x15,4
 544:	00f808b3          	add	x17,x16,x15
 548:	00f50733          	add	x14,x10,x15
 54c:	00878693          	addi	x13,x15,8
 550:	00072787          	flw	f15,0(x14) // Start of Iteration 0
 554:	00c80333          	add	x6,x16,x12
 558:	0008a607          	flw	f12,0(x17)
 55c:	00c502b3          	add	x5,x10,x12
 560:	00c78393          	addi	x7,x15,12
 564:	00032687          	flw	f13,0(x6) // Start of Iteration 1
 568:	00d80eb3          	add	x29,x16,x13
 56c:	00d50f33          	add	x30,x10,x13
 570:	0002a087          	flw	f1,0(x5)
 574:	000ea707          	flw	f14,0(x29) // Start of Iteration 2
 578:	000f2007          	flw	f0,0(x30)
 57c:	00780fb3          	add	x31,x16,x7
 580:	007508b3          	add	x17,x10,x7
 584:	78a67143          	fmadd.s	f2,f12,f10,f15
 588:	000fa187          	flw	f3,0(x31)
 58c:	0008a587          	flw	f11,0(x17) // Start of Iteration 3
 590:	08a6f243          	fmadd.s	f4,f13,f10,f1
 594:	00a772c3          	fmadd.s	f5,f14,f10,f0
 598:	58a1f343          	fmadd.s	f6,f3,f10,f11
 59c:	00f58733          	add	x14,x11,x15
 5a0:	00272027          	fsw	f2,0(x14) // End of Iteration 0
 5a4:	00c58633          	add	x12,x11,x12
 5a8:	00462027          	fsw	f4,0(x12) // End of Iteration 1
 5ac:	00d586b3          	add	x13,x11,x13
 5b0:	0056a027          	fsw	f5,0(x13) // End of Iteration 2
 5b4:	00758333          	add	x6,x11,x7
 5b8:	00632027          	fsw	f6,0(x6) // End of Iteration 3
        for(int i = 0;  i < 16; ++i) {
 5bc:	01078793          	addi	x15,x15,16
 5c0:	f9c790e3          	bne	x15,x28,540 <saxpy_restrict_restrict+0x10>
        }
}
 5c4:	00008067          	ret

*/


// If multdimensional arrays do not work (above) try flattening the
// array and using strided accesses. In the example below, A is 32
// elements long.

extern "C"
void saxpy_restrict_flat(float * __restrict A, float * __restrict C, float alpha) {
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * A[i] + A[i + 16];
        }
}

/*
Compiler: LLVM
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: Loads and stores are reordered correctly. 

void saxpy_restrict_flat(float * __restrict A, float * __restrict C, float alpha) {
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
 550:	04050513          	addi	x10,x10,64
 554:	00800613          	li	x12,8
 558:	04800693          	li	x13,72
                C[i] = alpha * A[i] + A[i + 16];
 55c:	00c50733          	add	x14,x10,x12
 560:	fb872007          	flw	f0,-72(x14) // Start of Iteration 0
 564:	10a07053          	fmul.s	f0,f0,f10
 568:	ff872087          	flw	f1,-8(x14)
 56c:	fbc72107          	flw	f2,-68(x14) // Start of Iteration 1
 570:	00107053          	fadd.s	f0,f0,f1
 574:	10a170d3          	fmul.s	f1,f2,f10
 578:	00c587b3          	add	x15,x11,x12
 57c:	ffc72107          	flw	f2,-4(x14)
 580:	fc072187          	flw	f3,-64(x14) // Start of Iteration 2
 584:	0020f0d3          	fadd.s	f1,f1,f2
 588:	10a1f153          	fmul.s	f2,f3,f10
 58c:	fc472187          	flw	f3,-60(x14) // Start of Iteration 3
 590:	00072207          	flw	f4,0(x14) 
 594:	10a1f1d3          	fmul.s	f3,f3,f10
 598:	00417153          	fadd.s	f2,f2,f4
 59c:	00472207          	flw	f4,4(x14)
 5a0:	fe07ac27          	fsw	f0,-8(x15) // End of Iteration 0
 5a4:	0041f053          	fadd.s	f0,f3,f4
 5a8:	fe17ae27          	fsw	f1,-4(x15) // End of Iteration 1
 5ac:	0027a027          	fsw	f2,0(x15)  // End of Iteration 2
        for(int i = 0;  i < 16; ++i) {
 5b0:	01060613          	addi	x12,x12,16
                C[i] = alpha * A[i] + A[i + 16];
 5b4:	0007a227          	fsw	f0,4(x15)  /// End of Iteration 3
        for(int i = 0;  i < 16; ++i) {
 5b8:	fad612e3          	bne	x12,x13,55c <saxpy_restrict_flat+0xc>
        }
}
 5bc:	00008067          	ret

 */


// Care should also be taken when functions could be inlined. In the
// example below, saxpy_inline calls saxpy_restrict (above), but
// saxpy_restrict is small enough that it is inlined. 

// Inlining saxpy_restrict discards __restrict qualifiers. The
// assembly generated does not reorder loads and stores. 

// To prevent inlining, use __attribute__ ((noinline)) on functions
// that you do not want to be inlined (saxpy_restrict in this example)

extern "C"
void saxpy_inline(float * A, float * B, float * C, float alpha) {
        saxpy_restrict(A, B, C, alpha);
}

/*
Compiler: LLVM
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: Inlining discards __restrict qualifiers, if the caller does
not have __restrict qualifiers.

extern "C"
void saxpy_inline(float * A, float * B, float * C, float alpha) {
 590:   00000793                li      x15,0
        for(int i = 0;  i < 16; ++i) {
 594:   04000f13                li      x30,64
                C[i] = alpha * A[i] + B[i];
 598:   00f506b3                add     x13,x10,x15
 59c:   00f58733                add     x14,x11,x15
 5a0:   0006a787                flw     f15,0(x13)
 5a4:   00072707                flw     f14,0(x14)
 5a8:   00478293                addi    x5,x15,4
 5ac:   00f60e33                add     x28,x12,x15
 5b0:   70f57043                fmadd.s f0,f10,f15,f14
 5b4:   00550333                add     x6,x10,x5
 5b8:   005588b3                add     x17,x11,x5
 5bc:   00878393                addi    x7,x15,8
 5c0:   00560833                add     x16,x12,x5
 5c4:   000e2027                fsw     f0,0(x28)
 5c8:   00032087                flw     f1,0(x6)
 5cc:   0008a107                flw     f2,0(x17)
 5d0:   00750eb3                add     x29,x10,x7
 5d4:   00758fb3                add     x31,x11,x7
 5d8:   101571c3                fmadd.s f3,f10,f1,f2
 5dc:   00c78713                addi    x14,x15,12
 5e0:   007606b3                add     x13,x12,x7
 5e4:   00e502b3                add     x5,x10,x14
 5e8:   00e58e33                add     x28,x11,x14
 5ec:   00382027                fsw     f3,0(x16)
 5f0:   000ea207                flw     f4,0(x29)
 5f4:   000fa287                flw     f5,0(x31)
 5f8:   00e60333                add     x6,x12,x14
 5fc:   01078793                addi    x15,x15,16
 600:   28457343                fmadd.s f6,f10,f4,f5
 604:   0066a027                fsw     f6,0(x13)
 608:   0002a387                flw     f7,0(x5)
 60c:   000e2587                flw     f11,0(x28)
 610:   58757643                fmadd.s f12,f10,f7,f11
 614:   00c32027                fsw     f12,0(x6)
        for(int i = 0;  i < 16; ++i) {
 618:   f9e790e3                bne     x15,x30,598 <saxpy_inline+0x8>
        saxpy_restrict(A, B, C, alpha);
}
 61c:   00008067                ret
 */


// The example below also works in both LLVM and GCC, as long as A has the __restrict qualifier
// extern "C"

extern "C"
void saxpy_cast(float * __restrict A, float * __restrict C, float alpha) {

        float (&xy)[2][16] = *reinterpret_cast<float (*)[2][16]> (A);
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
                C[i] = alpha * xy[0][i] + xy[1][i];
        }
}

/*

Compiler: LLVM
Flags: -O2 --target=riscv32 -march=rv32imaf -mabi=ilp32f -ffast-math -ffp-contract=fast -march=rv32imaf -fno-common

Result: The compiler keeps the __restrict qualifier through casts, if
used in the same method.


void saxpy_cast(float * __restrict A, float * __restrict C, float alpha) {
 63c:   00000613                li      x12,0

        float (&xy)[2][16] = *reinterpret_cast<float (*)[2][16]> (A);
        UNROLL(4)
        for(int i = 0;  i < 16; ++i) {
 640:   00858593                addi    x11,x11,8
 644:   04c50513                addi    x10,x10,76
 648:   04000693                li      x13,64
                C[i] = alpha * xy[0][i] + xy[1][i];
 64c:   00c50733                add     x14,x10,x12
 650:   fb472007                flw     f0,-76(x14)
 654:   10a07053                fmul.s  f0,f0,f10
 658:   ff472087                flw     f1,-12(x14)
 65c:   fb872107                flw     f2,-72(x14)
 660:   00107053                fadd.s  f0,f0,f1
 664:   10a170d3                fmul.s  f1,f2,f10
 668:   00c587b3                add     x15,x11,x12
 66c:   ff872107                flw     f2,-8(x14)
 670:   fbc72187                flw     f3,-68(x14)
 674:   0020f0d3                fadd.s  f1,f1,f2
 678:   10a1f153                fmul.s  f2,f3,f10
 67c:   fc072187                flw     f3,-64(x14)
 680:   ffc72207                flw     f4,-4(x14)
 684:   10a1f1d3                fmul.s  f3,f3,f10
 688:   00417153                fadd.s  f2,f2,f4
 68c:   00072207                flw     f4,0(x14)
 690:   fe07ac27                fsw     f0,-8(x15)
 694:   0041f053                fadd.s  f0,f3,f4
 698:   fe17ae27                fsw     f1,-4(x15)
 69c:   0027a027                fsw     f2,0(x15)
        for(int i = 0;  i < 16; ++i) {
 6a0:   01060613                addi    x12,x12,16
                C[i] = alpha * xy[0][i] + xy[1][i];
 6a4:   0007a227                fsw     f0,4(x15)
        for(int i = 0;  i < 16; ++i) {
 6a8:   fad612e3                bne     x12,x13,64c <saxpy_cast+0x10>
        }

}
 6ac:   00008067                ret
*/
