//This kernel sends an IO packets from each tile with the __bsg_x/y __bsg_grp_org_x/y __bsg_id 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h" 
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1); 

int  __attribute__ ((noinline)) kernel_packet() {

	bsg_remote_int_ptr origin_x_ptr;
	bsg_remote_int_ptr origin_y_ptr;

	origin_x_ptr = bsg_remote_ptr_control (__bsg_x, __bsg_y, CSR_TGO_X);
	origin_y_ptr = bsg_remote_ptr_control (__bsg_x, __bsg_y, CSR_TGO_Y);

	int origin_x = *origin_x_ptr;
	int origin_y = *origin_y_ptr;

	bsg_remote_ptr_io_store(IO_X_INDEX, 0x200, __bsg_x);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x400, __bsg_y);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x600, __bsg_grp_org_x);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x800, __bsg_grp_org_y);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x1000, origin_x);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x1200, origin_y);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x1400, __bsg_id);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x1600, __bsg_grid_dim_x);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x1800, __bsg_grid_dim_y);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x2000, __bsg_tile_group_id_x);
	bsg_remote_ptr_io_store(IO_X_INDEX, 0x2200, __bsg_tile_group_id_y);

	
	bsg_tile_group_barrier (&r_barrier, &c_barrier); 

  return 0;
}
