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

extern int *A __attribute__ ((section (".dram")));

////////////////////////////////////////////////////////////////////
int main() {
	bsg_set_tile_x_y();
	
	if (bsg_x == 0 && bsg_y == 0)
	{
		for (int idx = 0; idx < vector_size ; idx ++){
			A[idx] = 1 * idx ;
		}
	}
	else {
		bsg_wait_while(1);
	}
}


