#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int hello () {
    // only from core 0
    if (bsg_id == 0) {
        bsg_printf("hello from tile %d\n", bsg_id);
    }

    bsg_tile_group_barrier(&r_barrier, &c_barrier);
    
}
