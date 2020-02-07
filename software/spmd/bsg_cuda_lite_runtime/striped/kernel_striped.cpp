//This is an empty kernel

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_striped_array.hpp"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

using namespace bsg_manycore;

struct foo {
    int bar;
    int baz;
};

using Array = TileGroupStripedArray<struct foo, 16, bsg_tiles_X, bsg_tiles_Y, 2>;

extern "C" int  __attribute__ ((noinline)) kernel_striped() {
    Array data;
    if (bsg_id == 0) {
        for (int i = 0; i < data.size(); i++) {
            data[i].bar = 2*i;
            data[i].baz = 2*i+1;
        }
    }

    bsg_tile_group_barrier(&r_barrier, &c_barrier);
    for (int i = 0; i < Array::ELEMENTS_PER_TILE; i++) {
        bsg_print_int(data.at_local(i).bar);
        bsg_print_int(data.at_local(i).baz);
    }
    return 0;
}
