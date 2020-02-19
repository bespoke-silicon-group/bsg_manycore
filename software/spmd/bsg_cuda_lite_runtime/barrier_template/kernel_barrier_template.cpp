// This kernel performs a barrier among all tiles in tile group 
// Uses the new template barrier 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier_template.hpp"


extern "C" int  __attribute__ ((noinline)) kernel_barrier_template() {

        bsg_barrier<2,2> my_barrier (0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

	if (__bsg_id == 3) {
		bsg_print_int(3);
	}

        my_barrier.sync();

	if (__bsg_id == 0) {
		bsg_print_int(0);
	}

        my_barrier.sync();

	return 0;
}
