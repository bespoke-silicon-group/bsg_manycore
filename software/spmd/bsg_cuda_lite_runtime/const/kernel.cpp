// This kernel adds 2 vectors to demonstrate how the placement of
// const affects the compilation correctness of code

#include <bsg_manycore.h>
#include <cstdint>

// No const declarations
extern "C" __attribute__ ((noinline))
int kernel_vec_add(int *A,
                   int *B,
                   int *C,
                   int N)
{
        A = A; // Valid
        B = B; // Valid
        A[0] = A[0]; // Valid
        B[0] = B[0]; // Valid
        C = C; // Valid
        C[0] = C[0]; // Valid
	for (uint32_t idx; idx < N; idx ++){
                C[idx] = A[idx] + B[idx];
	}

	return 0;
}

/*
Compiler: GCC
Optimizations: -fweb -frename-registers -frerun-cse-after-loop -g -std=c++11 -O2

00000150 <kernel_vec_add>:
	for (uint32_t idx; idx < N; idx ++){
 150:	02068e63          	beqz	x13,18c <kernel_vec_add+0x3c>
 154:	00000713          	li	x14,0
 158:	00269693          	slli	x13,x13,0x2
 15c:	00e507b3          	add	x15,x10,x14
 160:	00e585b3          	add	x11,x11,x14
 164:	00e60633          	add	x12,x12,x14
 168:	00d50533          	add	x10,x10,x13
                C[idx] = A[idx] + B[idx];
 16c:	0007a283          	lw	x5,0(x15)
 170:	0005a303          	lw	x6,0(x11)
 174:	00478793          	addi	x15,x15,4
 178:	00458593          	addi	x11,x11,4
 17c:	006283b3          	add	x7,x5,x6
 180:	00762023          	sw	x7,0(x12)
	for (uint32_t idx; idx < N; idx ++){
 184:	00460613          	addi	x12,x12,4
 188:	fea792e3          	bne	x15,x10,16c <kernel_vec_add+0x1c>
	}

	return 0;
}
 18c:	00000513          	li	x10,0
 190:	00008067          	ret
*/

extern "C" __attribute__ ((noinline))
int kernel_vec_add_const(const int *A, // The data elements of A are constant (read-only)
                   int const *B, // Same as A, above
                   int * const C, // The pointer, C, is constant. Data is not.
                   int N)
{
        A = A; // Valid (Contents of A are not affected)
        B = B; // Valid (Contents of B are not affected)
        // A[0] = 0; // Invalid -- "error: assignment of read-only location '* B"
        // B[0] = 0; // Invalid -- "error: assignment of read-only location '* B"
        // C = C; // Invalid -- "error: assignment of read-only parameter"
	for (uint32_t idx; idx < N; idx ++){
                C[idx] = A[idx] + B[idx];
	}

	return 0;
}

/* 
Compiler: GCC
Optimizations: -fweb -frename-registers -frerun-cse-after-loop -g -O2

Disassembly is unchanged from above. Const has no effect on output.

00000194 <kernel_vec_add_const>:
        A = A; // Valid (Contents of A are not affected)
        B = B; // Valid (Contents of B are not affected)
        // A[0] = 0; // Invalid -- "error: assignment of read-only location '* B"
        // B[0] = 0; // Invalid -- "error: assignment of read-only location '* B"
        // C = C; // Invalid -- "error: assignment of read-only parameter"
	for (uint32_t idx; idx < N; idx ++){
 194:	02068e63          	beqz	x13,1d0 <kernel_vec_add_const+0x3c>
 198:	00000713          	li	x14,0
 19c:	00269693          	slli	x13,x13,0x2
 1a0:	00e507b3          	add	x15,x10,x14
 1a4:	00e585b3          	add	x11,x11,x14
 1a8:	00e60633          	add	x12,x12,x14
 1ac:	00d50533          	add	x10,x10,x13
                C[idx] = A[idx] + B[idx];
 1b0:	0007a283          	lw	x5,0(x15)
 1b4:	0005a303          	lw	x6,0(x11)
 1b8:	00478793          	addi	x15,x15,4
 1bc:	00458593          	addi	x11,x11,4
 1c0:	006283b3          	add	x7,x5,x6
 1c4:	00762023          	sw	x7,0(x12)
	for (uint32_t idx; idx < N; idx ++){
 1c8:	00460613          	addi	x12,x12,4
 1cc:	fea792e3          	bne	x15,x10,1b0 <kernel_vec_add_const+0x1c>
	}

	return 0;
}
 1d0:	00000513          	li	x10,0
 1d4:	00008067          	ret
*/

extern "C" __attribute__ ((noinline))
int kernel_vec_add_constconst(const int * const A, // The elements and pointer are constant (read-only)
                   int const * const B, // Same as A, above
                   int * const C, // The pointer, C, is constant. Data is not.
                   int N)
{
        // A = A; // Invalid
        // B = B; // Invalid
        // A[0] = 0; // Invalid -- "error: assignment of read-only location '* B"
        // B[0] = 0; // Invalid -- "error: assignment of read-only location '* B"
        // C = C; // Invalid -- "error: assignment of read-only parameter"

	for (uint32_t idx; idx < N*8; idx ++){
                C[idx] = A[idx] + B[idx];
	}

	return 0;
}

/*
Compiler: GCC
Optimizations: -fweb -frename-registers -frerun-cse-after-loop -g -O2

Disassembly is unchanged from above. Const has no effect on output.

000001d8 <kernel_vec_add_constconst>:
        // A = A; // Invalid
        // B = B; // Invalid
        // A[0] = 0; // Invalid -- "error: assignment of read-only location '* B"
        // B[0] = 0; // Invalid -- "error: assignment of read-only location '* B"
        // C = C; // Invalid -- "error: assignment of read-only parameter"
        for (uint32_t idx; idx < N*8; idx ++){
 1d8:   00369793                slli    x15,x13,0x3
 1dc:   02078e63                beqz    x15,218 <kernel_vec_add_constconst+0x40>
 1e0:   00000713                li      x14,0
 1e4:   00569693                slli    x13,x13,0x5
 1e8:   00e503b3                add     x7,x10,x14
 1ec:   00e585b3                add     x11,x11,x14
 1f0:   00e60633                add     x12,x12,x14
 1f4:   00d50533                add     x10,x10,x13
                C[idx] = A[idx] + B[idx];
 1f8:   0003a283                lw      x5,0(x7)
 1fc:   0005a303                lw      x6,0(x11)
 200:   00438393                addi    x7,x7,4
 204:   00458593                addi    x11,x11,4
 208:   00628833                add     x16,x5,x6
 20c:   01062023                sw      x16,0(x12)
        for (uint32_t idx; idx < N*8; idx ++){
 210:   00460613                addi    x12,x12,4
 214:   fea392e3                bne     x7,x10,1f8 <kernel_vec_add_constconst+0x20>
        }

        return 0;
}
 218:   00000513                li      x10,0
 21c:   00008067                ret
*/
