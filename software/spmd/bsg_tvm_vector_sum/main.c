#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BARRIER_X_START 		0
#define BARRIER_Y_START 		0

#define BARRIER_X_END			(bsg_tiles_X - 1)
#define BARRIER_Y_END			(bsg_tiles_Y - 1)
#define BARRIER_X_NUM			(BARRIER_X_END - BARRIER_X_START +1) 
#define BARRIER_Y_NUM			(BARRIER_Y_END - BARRIER_Y_START +1) 
#define BARRIER_TILES			(BARRIER_X_NUM * BARRIER_Y_NUM)

#define  BSG_BARRIER_DEBUG		1
#define  BSG_TILE_GROUP_X_DIM	BARRIER_X_NUM
#define  BSG_TILE_GROUP_Y_DIM	BARRIER_Y_NUM
#define  BSG_TILE_GROUP_Z_DIM	1
#define  BSG_TILE_GROUP_SIZE	(BSG_TILE_GROUP_X_DIM * BSG_TILE_GROUP_Y_DIM)
#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER (row_barrier_inst1, col_barrier_inst1, BARRIER_X_START, BARRIER_X_END, BARRIER_Y_START, BARRIER_Y_END);
INIT_TILE_GROUP_BARRIER (row_barrier_inst2, col_barrier_inst2, BARRIER_X_START, BARRIER_X_END, BARRIER_Y_START, BARRIER_Y_END);
INIT_TILE_GROUP_BARRIER (row_barrier_inst3, col_barrier_inst3, BARRIER_X_START, BARRIER_X_END, BARRIER_Y_START, BARRIER_Y_END);




#define vector_size 64



/***********************************************************************************************************************************************************************
1. Allocate memory on Hammerblade DRAM.
The main() and allocation together simulate the host side - which allocates and initializes memory on the HBMC DRAM,
and launches the kernel on the hammerblade manycore, while passing in the pointers for the memory on DRAM. 
Ultimately this will be done on the Host.
***********************************************************************************************************************************************************************/
int A[vector_size] __attribute__ ((section (".dram"))) = { -1, 1, 0xF, 0x80000000};
int B[vector_size] __attribute__ ((section (".dram"))) = { -1, 1, 0xF, 0x80100000};
int C[vector_size] __attribute__ ((section (".dram"))) = { -1, 1, 0xF, 0x80200000};	


////////////////////////////////////////////////////////////////////
int main() {

	bsg_set_tile_x_y();
	
	/***********************************************************************************************************************************************************************
	2. Tile (0,0) initializes A and B arrays. Ultimately, A & B will be initialized on the host.
	***********************************************************************************************************************************************************************/
	if (bsg_x == 0 && bsg_y == 0)
	{
		for (int idx = 0; idx < vector_size ; idx ++){
			A[idx] = 1 * idx ;
			B[idx] = 2 * idx ;
		}
	}

	
	/***********************************************************************************************************************************************************************
	3. Synchronize all tiles and threads. This is only necessary here since a tile is initializing memories. It won't be needed when this section moves to the host.
	***********************************************************************************************************************************************************************/		
	bsg_tile_group_barrier(&row_barrier_inst1, &col_barrier_inst1);

	
	/***********************************************************************************************************************************************************************
	4. Launch kernel and pass the pointers.
	***********************************************************************************************************************************************************************/		
	kernel(A, B, C, vector_size) ;
	
	

	/***********************************************************************************************************************************************************************
	5. Kernel returns from device. 
	   Tile (0,0) outputs the result. Ultimately, this will be done by the host.
	***********************************************************************************************************************************************************************/			
	if (bsg_x == 0 && bsg_y == 0){
		for (int idx = 0 ; idx < vector_size; idx ++)
			bsg_printf("C[%d] = %d\n", idx, C[idx]);
	}
	
	/***********************************************************************************************************************************************************************
	6. Synchronize and terminate. 
	   Whoever finishes first, will terminate simulation.
	***********************************************************************************************************************************************************************/	
	bsg_tile_group_barrier(&row_barrier_inst3, &col_barrier_inst3);
	bsg_finish();
	bsg_wait_while(1);	
}




/***********************************************************************************************************************************************************************
****DISCLAIMER****: This is not model CUDA-Lite code, this is just showing a translation from TVM-generated CUDA code, which has its own idiosyncrasies.
***********************************************************************************************************************************************************************/
int kernel(int *A, int *B, int *C, int n){



	const int k_gridDim_x = 1;			// 16
	const int k_gridDim_y = 1;
	const int k_gridDim_z = 1;
	const int k_blockDim_x = 64;		// 64
	const int k_blockDim_y = 1;			// 1
	const int k_blockDim_z = 1;
	const int blockIdx_x = 0;
	const int blockIdx_y = 0 ;
	const int blockIdx_z = 0 ;
	const int bsg_z = 0 ;
	const int num_threads_x = (k_blockDim_x / BSG_TILE_GROUP_X_DIM) ;
	const int num_threads_y = (k_blockDim_y / BSG_TILE_GROUP_Y_DIM) ;
	const int num_threads_z = (k_blockDim_z / BSG_TILE_GROUP_Z_DIM) ;

	
	
	int id = bsg_x_y_to_id(bsg_x,bsg_y);


	
	/***********************************************************************************************************************************************************************
	Perform vector addition. 
	***********************************************************************************************************************************************************************/		
	for (int iter_z = bsg_z; iter_z < k_blockDim_z; iter_z+= BSG_TILE_GROUP_Z_DIM){
		for (int iter_y = bsg_y; iter_y < k_blockDim_y ; iter_y+= BSG_TILE_GROUP_Y_DIM){
			for (int iter_x = bsg_x; iter_x < k_blockDim_x; iter_x+= BSG_TILE_GROUP_X_DIM){			
				if ( blockIdx_x < n/64){
					C[((((int)blockIdx_x) * 64) + ((int)iter_x))] = A[((((int)blockIdx_x) * 64) + ((int)iter_x))] + B[((((int)blockIdx_x) * 64) + ((int)iter_x))];
				}            
				else{
					if ((((int)blockIdx_x) * k_blockDim_x) < ( n -((int)iter_x))){
						C[((((int)blockIdx_x) * k_blockDim_x) + ((int)iter_x))] = A[((((int)blockIdx_x) * k_blockDim_x) + ((int)iter_x))] + B[((((int)blockIdx_x) * k_blockDim_x) + ((int)iter_x))];
					}
				}
			}
		}
	}
	
	
	/***********************************************************************************************************************************************************************
	Synchronize to make sure all threads have finished execution before returning to host.
	***********************************************************************************************************************************************************************/		
	bsg_tile_group_barrier(&row_barrier_inst2, &col_barrier_inst2);
}





