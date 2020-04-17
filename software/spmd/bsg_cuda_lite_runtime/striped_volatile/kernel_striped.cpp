//This is an empty kernel

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_striped_array.hpp"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

using namespace bsg_manycore;

// uncomment this out and the test will hang
//using Array = TileGroupStripedArray<int, 4, bsg_tiles_X, bsg_tiles_Y, 1>;

// using the volatile version of the striped array to notify the compiler that other
// tiles may modify the array's contents
using Array = VolatileTileGroupStripedArray<int, 4, bsg_tiles_X, bsg_tiles_Y, 1>;

extern "C" __attribute__ ((noinline))
int kernel_striped_volatile() {
    Array data;

    if (bsg_id == 0)
        data[0] = 0xDEADBEEF;

    while (data[0] != 0xDEADBEEF);

    barrier.sync();

    return 0;
}
