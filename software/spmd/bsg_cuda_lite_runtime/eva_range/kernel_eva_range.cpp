/////////////////////////////////////////////////////////////////////////
// This kernel copies a single word from one memory address to another //
/////////////////////////////////////////////////////////////////////////

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define bsg_n (bsg_tiles_X * bsg_tiles_Y)

extern "C" __attribute__ ((noinline)) 
int kernel_eva_range(
    // in
    const unsigned * ptr,
    // out
    unsigned * value_read_ptr
    ) {
    bsg_print_hexadecimal(reinterpret_cast<unsigned>(ptr));
    bsg_print_hexadecimal(reinterpret_cast<unsigned>(value_read_ptr));
    *value_read_ptr = *ptr;
    return 0;
}
