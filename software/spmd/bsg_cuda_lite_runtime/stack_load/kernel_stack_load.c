//This kernel tests to make sure elements loaded through stack are correct
//If the test fails the execution hangs

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel_stack_load(int N, int sum, int a1, int a2, int a3, int a4, int a5, int a6, int a7, int a8, int a9, int a10, int a11, int a12, int a13, int a14) {

	int res = a1 + a2 + a3 + a4 + a5 + a6 + a7 + a8 + a9 + a10 + a11 + a12 + a13 + 14;
	if (sum != res) { 
		while (1);
	}

	return 0;
}
