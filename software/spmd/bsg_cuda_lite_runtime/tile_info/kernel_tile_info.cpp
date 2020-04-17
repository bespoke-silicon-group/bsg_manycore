//This kernel sends an IO packets from each tile with the __bsg_x/y __bsg_grp_org_x/y __bsg_id 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include "bsg_tile_group_barrier.hpp" 

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" __attribute__ ((noinline))
int kernel_tile_info() {

	bsg_remote_int_ptr origin_x_ptr;
	bsg_remote_int_ptr origin_y_ptr;

	origin_x_ptr = bsg_remote_ptr_control (__bsg_x, __bsg_y, CSR_TGO_X);
	origin_y_ptr = bsg_remote_ptr_control (__bsg_x, __bsg_y, CSR_TGO_Y);

	int origin_x = *origin_x_ptr;
	int origin_y = *origin_y_ptr;

	bsg_printf("x:%d\n", __bsg_x);
	bsg_printf("y:%d\n", __bsg_y);
	bsg_printf("id: %d\n", __bsg_id);
	bsg_printf("org_x: %d\n", __bsg_grp_org_x);
	bsg_printf("org_y: %d\n", __bsg_grp_org_y);
	bsg_printf("CSR_x: %d\n", origin_x);
	bsg_printf("CSR_y: %d\n", origin_y);
	bsg_printf("g_id_x: %d\n", __bsg_grid_dim_x);
	bsg_printf("g_id_y: %d\n", __bsg_grid_dim_y);
	bsg_printf("tg_id_x: %d\n", __bsg_tile_group_id_x);
	bsg_printf("tg_id_y: %d\n", __bsg_tile_group_id_y);

	barrier.sync();

  return 0;
}
