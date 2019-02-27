


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BARRIER_X_START 		0
#define BARRIER_Y_START 		0

#define BARRIER_X_END			(bsg_tiles_X - 1)
#define BARRIER_Y_END			(bsg_tiles_Y - 1)
#define BARRIER_X_NUM			(BARRIER_X_END - BARRIER_X_START +1) 
#define BARRIER_Y_NUM			(BARRIER_Y_END - BARRIER_Y_START +1) 
#define BARRIER_TILES			( BARRIER_X_NUM * BARRIER_Y_NUM )

#define  BSG_BARRIER_DEBUG		1
#define  BSG_TILE_GROUP_X_DIM	BARRIER_X_NUM
#define  BSG_TILE_GROUP_Y_DIM	BARRIER_Y_NUM
#define  BSG_TILE_GROUP_Z_DIM	1
#define  BSG_TILE_GROUP_SIZE	(BSG_TILE_GROUP_X_DIM * BSG_TILE_GROUP_Y_DIM)
#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER (row_barrier_inst1, col_barrier_inst1, BARRIER_X_START, BARRIER_X_END, BARRIER_Y_START, BARRIER_Y_END);
INIT_TILE_GROUP_BARRIER (row_barrier_inst2, col_barrier_inst2, BARRIER_X_START, BARRIER_X_END, BARRIER_Y_START, BARRIER_Y_END);
INIT_TILE_GROUP_BARRIER (row_barrier_inst3, col_barrier_inst3, BARRIER_X_START, BARRIER_X_END, BARRIER_Y_START, BARRIER_Y_END);


#define  gridDim_x				1		// 16
#define  gridDim_y				1
#define  gridDim_z				1
#define  blockDim_x				64		// 64
#define  blockDim_y				1		// 1
#define  blockDim_z				1
#define  blockIdx_x				0
#define  blockIdx_y				0
#define  blockIdx_z				0
#define  bsg_z					0
#define num_threads_x			blockDim_x / BSG_TILE_GROUP_X_DIM
#define num_threads_y			blockDim_x / BSG_TILE_GROUP_Y_DIM
#define num_threads_z			blockDim_x / BSG_TILE_GROUP_Z_DIM
#define  n 						64		// 1024






int A[n] __attribute__ ((section (".dram"))) = { -1, 1, 0xF, 0x80000000};
int B[n] __attribute__ ((section (".dram"))) = { -1, 1, 0xF, 0x80100000};
int C[n] __attribute__ ((section (".dram"))) = { -1, 1, 0xF, 0x80200000};



////////////////////////////////////////////////////////////////////
int main() {


	bsg_set_tile_x_y();
	int id = bsg_x_y_to_id(bsg_x,bsg_y);

	if(  (bsg_x>= BARRIER_X_START  && bsg_x <= BARRIER_X_END) && (bsg_y>= BARRIER_Y_START  && bsg_y <= BARRIER_Y_END)   ){
	
	
	
		/******************************************************************************************************************************
		1. Initialize A and B arrays. This is not necessary in the final version, as A & B will be initialized by the host.
		******************************************************************************************************************************/
		for (int it_z = bsg_z; it_z < blockDim_z; it_z+= BSG_TILE_GROUP_Z_DIM){
			for (int it_y = bsg_y; it_y < blockDim_y ; it_y+= BSG_TILE_GROUP_Y_DIM){
				for (int it_x = bsg_x; it_x < blockDim_x; it_x+= BSG_TILE_GROUP_X_DIM){					
					if ( blockIdx_x < n/64){
						A[((((int)blockIdx_x) * 64) + ((int)it_x))] = ( 1 * ((((int)blockIdx_x) * 64) + ((int)it_x)));
						B[((((int)blockIdx_x) * 64) + ((int)it_x))] = ( 2 * ((((int)blockIdx_x) * 64) + ((int)it_x)));	
					}            
					else{
						if ((((int)blockIdx_x) * blockDim_x) < ( n -((int)it_x))){
							A[((((int)blockIdx_x) * 64) + ((int)it_x))] = ( 1 * ((((int)blockIdx_x) * 64) + ((int)it_x)));
							B[((((int)blockIdx_x) * 64) + ((int)it_x))] = ( 2 * ((((int)blockIdx_x) * 64) + ((int)it_x)));							
						}
					}
				}
			}
		}
		
		
		/******************************************************************************************************************************
		2. Synchronize all tiles and threads. 
		******************************************************************************************************************************/		
		bsg_tile_group_barrier(&row_barrier_inst1, &col_barrier_inst1);

		
		/******************************************************************************************************************************
		3. Perform vector addition. 
		******************************************************************************************************************************/		
		for (int it_z = bsg_z; it_z < blockDim_z; it_z+= BSG_TILE_GROUP_Z_DIM){
			for (int it_y = bsg_y; it_y < blockDim_y ; it_y+= BSG_TILE_GROUP_Y_DIM){
				for (int it_x = bsg_x; it_x < blockDim_x; it_x+= BSG_TILE_GROUP_X_DIM){			
					if ( blockIdx_x < n/64){
						C[((((int)blockIdx_x) * 64) + ((int)it_x))] = A[((((int)blockIdx_x) * 64) + ((int)it_x))] + B[((((int)blockIdx_x) * 64) + ((int)it_x))];
					}            
					else{
						if ((((int)blockIdx_x) * blockDim_x) < ( n -((int)it_x))){
							C[((((int)blockIdx_x) * blockDim_x) + ((int)it_x))] = A[((((int)blockIdx_x) * blockDim_x) + ((int)it_x))] + B[((((int)blockIdx_x) * blockDim_x) + ((int)it_x))];
						}
					}
				}
			}
		}


		/******************************************************************************************************************************
		4. Synchronize all tiles and threads. 
		******************************************************************************************************************************/		
		bsg_tile_group_barrier(&row_barrier_inst2, &col_barrier_inst2);
		

		/******************************************************************************************************************************
		5. Tile (0,0) outputs the result. 
		******************************************************************************************************************************/			
		if ( id == 0 ){
			for (int idx = 0 ; idx < n; idx ++)
				bsg_printf("C[%d] = %d\n", idx, C[idx]);
		}
		
		/******************************************************************************************************************************
		6. Synchronize and terminate. 
		   Whoever finishes first, will terminate simulation.
		******************************************************************************************************************************/	
		bsg_tile_group_barrier(&row_barrier_inst3, &col_barrier_inst3);
		bsg_finish();
		
	}

	bsg_wait_while(1);
}






