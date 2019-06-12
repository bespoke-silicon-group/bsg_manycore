#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>

#define N 64



#define flt(X) (*(float*)&X)
#define hex(X) (*(int*)&X)



float sample_A[N] __attribute__ ((section (".dram"))) = {
43.00, -42.00, 11.00, -13.00, 
12.00, -3.00, -15.00, -29.00, 
-25.00, 16.00, -1.00, 17.00, 
22.00, 26.00, -42.00, -29.00, 
-14.00, -45.00, 3.00, 42.00, 
28.00, 25.00, 39.00, 12.00, 
-30.00, -41.00, -7.00, -16.00, 
-38.00, -45.00, -5.00, -17.00, 
-34.00, 39.00, 48.00, 16.00, 
-11.00, 7.00, -3.00, -3.00, 
34.00, 48.00, -28.00, -44.00, 
49.00, -18.00, 20.00, -49.00, 
6.00, 13.00, -14.00, -39.00, 
34.00, 3.00, -24.00, 3.00, 
1.00, -15.00, 26.00, 23.00, 
-50.00, 20.00, 44.00, -17.00
};





float sample_B[N] __attribute__ ((section (".dram"))) = {
5.00, -31.00, -48.00, -12.00, 
48.00, -2.00, -42.00, -29.00, 
2.00, 22.00, -41.00, -42.00, 
-1.00, -37.00, -34.00, 4.00, 
-12.00, 46.00, 0.00, -7.00, 
-31.00, -35.00, -5.00, 24.00, 
-33.00, 18.00, -29.00, 15.00, 
36.00, 28.00, -39.00, -26.00, 
-11.00, 49.00, -5.00, 12.00, 
5.00, -42.00, 22.00, 49.00, 
3.00, 28.00, -33.00, -48.00, 
11.00, 15.00, 48.00, 23.00, 
-24.00, 45.00, -9.00, -37.00, 
29.00, 37.00, 38.00, -2.00, 
-41.00, -9.00, -1.00, 27.00, 
-4.00, -22.00, -13.00, 2.00
};





float sample_C[N] __attribute__ ((section (".dram"))) = {
48.00, -73.00, -37.00, -25.00, 
60.00, -5.00, -57.00, -58.00, 
-23.00, 38.00, -42.00, -25.00, 
21.00, -11.00, -76.00, -25.00, 
-26.00, 1.00, 3.00, 35.00, 
-3.00, -10.00, 34.00, 36.00, 
-63.00, -23.00, -36.00, -1.00, 
-2.00, -17.00, -44.00, -43.00, 
-45.00, 88.00, 43.00, 28.00, 
-6.00, -35.00, 19.00, 46.00, 
37.00, 76.00, -61.00, -92.00, 
60.00, -3.00, 68.00, -26.00, 
-18.00, 58.00, -23.00, -76.00, 
63.00, 40.00, 14.00, 1.00, 
-40.00, -24.00, 25.00,50.00, 
-54.00, -2.00, 31.00, -15.00
};















#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);



float A[N] __attribute__ ((section (".dram")));
float B[N] __attribute__ ((section (".dram")));
float C[N] __attribute__ ((section (".dram")));


void initialize_input (float *A, float *B, float *C, float size) { 
	for (int i = __bsg_id; i < size; i += bsg_tiles_X * bsg_tiles_Y) {
		A[i] = sample_A[i];
		B[i] = sample_B[i];
		C[i] = 0.0; 
	}
	return;
}


void vector_add (float *A, float *B, float *C, float size) { 

	for (int i = __bsg_id; i < size; i += bsg_tiles_X * bsg_tiles_Y) { 
		C[i] = A[i] + B[i];
	}	
	return;
}



int main()
{
	bsg_set_tile_x_y();


	initialize_input(A, B, C, N);


	bsg_tile_group_barrier(&r_barrier, &c_barrier); 


	vector_add (A, B, C, N); 


	bsg_tile_group_barrier(&r_barrier, &c_barrier); 

	
	int mismatch = 0;
	if (__bsg_id == 0) { 
		for (int i = 0; i < N; i ++) { 
			if (C[i] != sample_C[i]) { 
				bsg_printf("FAIL -- C[%d] = 0x%x\t Expected: 0x%x.\n", i, hex(C[i]), hex(sample_C[i]));
				mismatch = 1;
			}
		}
	}
	

	bsg_tile_group_barrier(&r_barrier, &c_barrier); 


	if (__bsg_id == 0) { 
		if (mismatch) {
			bsg_fail();
		}
	}

	bsg_finish();


	bsg_wait_while(1);
}
