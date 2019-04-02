// This code shows an example use of the bsg_tilegroup_int primitive.
// bsg_tilegroup_int declares a tilegroup-shared array with the desired size, that is evenly distributed among tiles in a tilegroup using a specific hash function.
// Access to tilegroup-shared memory is done through bsg_tilegroup_load and bsg_tilegroup_store primitives, that take in the pointer to local variable and the index.





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
#define  BSG_TILE_GROUP_SIZE	(BSG_TILE_GROUP_X_DIM * BSG_TILE_GROUP_Y_DIM)
#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER (row_barrier_inst, col_barrier_inst, BARRIER_X_START, BARRIER_X_END, BARRIER_Y_START, BARRIER_Y_END);







////////////////////////////////////////////////////////////////////
int main() {

	bsg_set_tile_x_y();
	
	int id = bsg_x_y_to_id(bsg_x,bsg_y);

	//if( (bsg_x < BSG_TILE_GROUP_X_DIM) && (bsg_y < BSG_TILE_GROUP_Y_DIM) ){
	if(  (bsg_x>= BARRIER_X_START  && bsg_x <= BARRIER_X_END) && (bsg_y>= BARRIER_Y_START  && bsg_y <= BARRIER_Y_END)   ){
	
		int local_var[64];
		
		

        //----------------------------------------------------------------
        //1. Setup shared memory.
        //----------------------------------------------------------------
		int *shared_mem;
		bsg_tilegroup_int(shared_mem, 67);
		

		
        //----------------------------------------------------------------
        //2. Initialize elements 2-17 of tilegroup-shared memory 
		//   Each tile stores its id to sh_mem[id+2] (which is in local memory of two tiles ahead)
		//    Store to Shared Mem
        //----------------------------------------------------------------
		bsg_tilegroup_store(shared_mem,(id+2),id);
				
				
        //----------------------------------------------------------------
        //3. Sync the group
        //----------------------------------------------------------------
        bsg_tile_group_barrier(&row_barrier_inst, &col_barrier_inst);

        //----------------------------------------------------------------
        //4. Each tile loads the first 16 elements of shared memory into local memory 	
        //----------------------------------------------------------------		
		for (int idx = 0; idx < 16 ; idx ++ )
			bsg_tilegroup_load(shared_mem,idx,local_var[idx]);
		

        //----------------------------------------------------------------
        //5. Sync the group
        //----------------------------------------------------------------		
        bsg_tile_group_barrier(&row_barrier_inst, &col_barrier_inst);

		
        //----------------------------------------------------------------
        //6. Check print
        //----------------------------------------------------------------			
		if ( id == 0)
		{
			for ( int idx = 0; idx < 16 ; idx ++)
				bsg_printf( "Check Print:\tsh_mem[%d] = %d\n" , idx , local_var[idx]) ;
		}
		
        //----------------------------------------------------------------
        //7. Sync the group
        //----------------------------------------------------------------			
        bsg_tile_group_barrier(&row_barrier_inst, &col_barrier_inst);

        //----------------------------------------------------------------
        //8. Tile 0 finished the execution
        //----------------------------------------------------------------
		if( id == 0) 
			bsg_finish();
		
	}

	bsg_wait_while(1);
}

