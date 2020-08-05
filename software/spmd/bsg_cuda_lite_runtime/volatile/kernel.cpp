//This kernel adds 2 vectors 

#include <bsg_manycore.h>
#include <bsg_set_tile_x_y.h>
#include <cstdint>


extern "C" __attribute__ ((noinline))
int kernel_vec_add(int *A,
                   int *B,
                   int *C,
                   int N)
{
        A[0]; // Optimized out
        B[0]; // Optimized out
        C[0]; // Optimized out
	for (uint32_t idx; idx < N; idx ++){
                C[idx] = A[idx] + B[idx];
	}

	return 0;
}

/*
Compiler: GCC
Optimizations: -fweb -frename-registers -frerun-cse-after-loop -g -std=c++11 -O2

00000150 <kernel_vec_add>:
                   int N)
{
        A[0]; // Optimized out
        B[0]; // Optimized out
        C[0]; // Optimized out
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
int kernel_vec_add_volatile(volatile int *A, // The data elements of A are volatile
                   int volatile *B, // Same as above
                   int * volatile C, // The pointer, C, is volatile. Data is not.
                   int N)
{
        A[0]; // A[0] will be re-read every time
        B[0]; // B[0] will be re-read every time
        C[0]; // The pointer C will be re-read every time, but not the 0th element (optimized out)
	for (uint32_t idx; idx < N; idx ++){
                C[idx] = A[idx] + B[idx];
	}

	return 0;
}

/*
Compiler: GCC
Optimizations: -fweb -frename-registers -frerun-cse-after-loop -g -std=c++11 -O2

00000194 <kernel_vec_add_volatile>:
extern "C" __attribute__ ((noinline))
int kernel_vec_add_volatile(volatile int *A, // The data elements of A are volatile
                   int volatile *B, // Same as above
                   int * volatile C, // The pointer, C, is volatile. Data is not.
                   int N)
{
 194:	ff010113          	addi	x2,x2,-16
 198:	00c12623          	sw	x12,12(x2)
        A[0]; // A[0] will be re-read every time
 19c:	00052783          	lw	x15,0(x10)
        B[0]; // B[0] will be re-read every time
 1a0:	0005a783          	lw	x15,0(x11)
        C[0]; // The pointer C will be re-read every time, but not the 0th element (optimized out)
 1a4:	00c12783          	lw	x15,12(x2)
	for (uint32_t idx; idx < N; idx ++){
 1a8:	02068a63          	beqz	x13,1dc <kernel_vec_add_volatile+0x48>
 1ac:	00000793          	li	x15,0
 1b0:	00269813          	slli	x16,x13,0x2
                C[idx] = A[idx] + B[idx];
 1b4:	00f506b3          	add	x13,x10,x15
 1b8:	00f58733          	add	x14,x11,x15
 1bc:	0006a283          	lw	x5,0(x13)
 1c0:	00072603          	lw	x12,0(x14)
 1c4:	00c12303          	lw	x6,12(x2)
 1c8:	00c283b3          	add	x7,x5,x12
 1cc:	00f308b3          	add	x17,x6,x15
 1d0:	0078a023          	sw	x7,0(x17)
	for (uint32_t idx; idx < N; idx ++){
 1d4:	00478793          	addi	x15,x15,4
 1d8:	fd079ee3          	bne	x15,x16,1b4 <kernel_vec_add_volatile+0x20>
	}

	return 0;
}
 1dc:	00000513          	li	x10,0
 1e0:	01010113          	addi	x2,x2,16
 1e4:	00008067          	ret
*/

extern "C" __attribute__ ((noinline))
int kernel_vec_add_volatile_volatile(volatile int *A, // The data elements of A are volatile
                   int volatile *B, // Same as above
                   volatile int * volatile C, // The pointer, C, is volatile. Data is not.
                   int N)
{
        A[0]; // A[0] will be re-read every time
        B[0]; // B[0] will be re-read every time
        C[0]; // The pointer C and C[0] will be re-read every time
	for (uint32_t idx; idx < N; idx ++){
                C[idx] = A[idx] + B[idx];
	}

	return 0;
}

/*
Compiler: GCC
Optimizations: -fweb -frename-registers -frerun-cse-after-loop -g -std=c++11 -O2

000001e8 <kernel_vec_add_volatile_volatile>:
extern "C" __attribute__ ((noinline))
int kernel_vec_add_volatile_volatile(volatile int *A, // The data elements of A are volatile
                   int volatile *B, // Same as above
                   volatile int * volatile C, // The pointer, C, is volatile. Data is not.
                   int N)
{
 1e8:	ff010113          	addi	x2,x2,-16
 1ec:	00c12623          	sw	x12,12(x2)
        A[0]; // A[0] will be re-read every time
 1f0:	00052783          	lw	x15,0(x10)
        B[0]; // B[0] will be re-read every time
 1f4:	0005a783          	lw	x15,0(x11)
        C[0]; // The pointer C and C[0] will be re-read every time
 1f8:	00c12783          	lw	x15,12(x2)
 1fc:	0007a783          	lw	x15,0(x15)
	for (uint32_t idx; idx < N; idx ++){
 200:	02068a63          	beqz	x13,234 <kernel_vec_add_volatile_volatile+0x4c>
 204:	00000e13          	li	x28,0
 208:	00269813          	slli	x16,x13,0x2
                C[idx] = A[idx] + B[idx];
 20c:	01c506b3          	add	x13,x10,x28
 210:	01c58733          	add	x14,x11,x28
 214:	0006a283          	lw	x5,0(x13)
 218:	00072603          	lw	x12,0(x14)
 21c:	00c12303          	lw	x6,12(x2)
 220:	00c283b3          	add	x7,x5,x12
 224:	01c308b3          	add	x17,x6,x28
 228:	0078a023          	sw	x7,0(x17)
	for (uint32_t idx; idx < N; idx ++){
 22c:	004e0e13          	addi	x28,x28,4
 230:	fd0e1ee3          	bne	x28,x16,20c <kernel_vec_add_volatile_volatile+0x24>
	}

	return 0;
}
 234:	00000513          	li	x10,0
 238:	01010113          	addi	x2,x2,16
 23c:	00008067          	ret
*/

