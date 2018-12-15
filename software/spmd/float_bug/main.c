#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define PI 3.14

float fft_arr[2] = {0.5, 0.25};

int main()
{
    bsg_set_tile_x_y();

    if ((bsg_x == bsg_tiles_X-1) && (bsg_y == bsg_tiles_Y-1)) {
        float y = fft_arr[0] + fft_arr[1];
        bsg_remote_ptr_io_store(IO_X_INDEX, 0x300, y);
        bsg_finish();
    }
    bsg_wait_while(1);
}

