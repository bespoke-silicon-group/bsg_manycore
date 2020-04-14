//This is an empty kernel

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_striped_array.hpp"

#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

using namespace bsg_manycore;

struct foo {
    int bar;
    int baz;
};

using Array = TileGroupStripedArray<struct foo, 16, bsg_tiles_X, bsg_tiles_Y, 2>;

extern "C" __attribute__ ((noinline))
int kernel_striped() {
    Array data;
    if (bsg_id == 0) {
        for (int i = 0; i < data.size(); i++) {
            data[i].bar = 2*i;
            data[i].baz = 2*i+1;
        }
    }

    barrier.sync();
    for (int i = 0; i < Array::ELEMENTS_PER_TILE; i++) {
        bsg_print_int(data.at_local(i).bar);
        bsg_print_int(data.at_local(i).baz);
    }
    return 0;
}
