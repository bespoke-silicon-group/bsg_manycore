
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_group_strider.hpp"
#include <algorithm>
#include "bsg_barrier_amoadd.h"

// AMOADD barrier
extern void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;

int main()
{

        bsg_set_tile_x_y();
        bsg_fence();
        bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm);  
        
        bsg_tile_group_strider<BSG_TILE_GROUP_X_DIM, 1, BSG_TILE_GROUP_Y_DIM, 0, int> stride_x(&__bsg_x, 0, 0);
        bsg_tile_group_strider<BSG_TILE_GROUP_X_DIM, 0, BSG_TILE_GROUP_Y_DIM, 1, int> stride_y(&__bsg_y, 0, 0);
        bsg_tile_group_strider<BSG_TILE_GROUP_X_DIM, 1, BSG_TILE_GROUP_Y_DIM, 1, int> stride_xy(&__bsg_y, 0, 0);
        bsg_printf("%d, %d\n", __bsg_y, __bsg_x);

        if ((__bsg_x == 0) && (__bsg_y == 0)) {

                // Stride vertically between tiles
                for (int i = 1; i <= bsg_tiles_Y; i++){
                        int cur = *stride_y.stride();
                        bsg_printf("Tile (%d, %d) @ Tile (%d, %d), __bsg_y = %d\n", __bsg_y, __bsg_x, i, 0, cur);
                        // The strider will wrap around to 0 at the edge of the tile group
                        if((i % bsg_tiles_Y) != cur)
                                bsg_fail();
                }

                // Stride horizontally
                for (int i = 1; i <= bsg_tiles_X; i++){
                        int cur = *stride_x.stride();
                        bsg_printf("Tile (%d, %d) @ Tile (%d, %d), __bsg_y = %d\n", __bsg_y, __bsg_x, 0, i, cur);
                        // The strider will wrap around to 0 at the edge of the tile group
                        if((i % bsg_tiles_X) != cur)
                                bsg_fail();
                }

                // Stride diagonally, no wrap 
                int lim = std::min(bsg_tiles_X, bsg_tiles_Y);
                for (int i = 1; i < lim; i++){
                        int cur = *stride_xy.stride();
                        bsg_printf("Tile (%d, %d) @ Tile (%d, %d), __bsg_y = %d\n", __bsg_y, __bsg_x, i, i, cur);
                        if(i != cur)
                                bsg_fail();
                }
  
                bsg_finish();
        }

        bsg_wait_while(1);

}

