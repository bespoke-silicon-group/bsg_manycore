//This is an empty kernel

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_striped_array.hpp"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

using namespace bsg_manycore;

// uncomment this out and the test will hang
//using Array = TileGroupStripedArray<int, 4, bsg_tiles_X, bsg_tiles_Y, 1>;

// using the volatile version of the striped array to notify the compiler that other
// tiles may modify the array's contents
using Array = VolatileTileGroupStripedArray<int, 4, bsg_tiles_X, bsg_tiles_Y, 1>;

extern "C" int  __attribute__ ((noinline)) kernel_striped_volatile() {
    Array data;

    if (bsg_id == 0)
        data[0] = 0xDEADBEEF;

    while (data[0] != 0xDEADBEEF);

    bsg_tile_group_barrier(&r_barrier, &c_barrier);

    return 0;
}
