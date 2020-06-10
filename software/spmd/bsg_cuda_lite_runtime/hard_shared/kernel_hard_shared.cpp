// This kernel performs tests hardware tile group shared memory.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier.hpp"
#include "bsg_shared_mem.hpp"

using namespace bsg_manycore;

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

extern "C" int  __attribute__ ((noinline)) kernel_hard_shared() {


    TileGroupSharedMem<int, 64, bsg_tiles_X, bsg_tiles_Y, 8> A;

//    if (__bsg_id == 0) {
//        bsg_print_hexadecimal(A._local_addr);
//    }
//
    if (__bsg_id == 0) {
        A[0] = 0x32;
    }

//    bsg_print_hexadecimal(A._local_addr);
//    bsg_print_hexadecimal(reinterpret_cast<int> (A._addr));
//    bsg_print_hexadecimal(reinterpret_cast<int> (A[1]));
//    bsg_print_hexadecimal(reinterpret_cast<int> (A[2]));
//    bsg_print_hexadecimal(reinterpret_cast<int> (A[3]));
//    bsg_print_hexadecimal(reinterpret_cast<int> (A[4]));


    barrier.sync();
    return 0;
}
