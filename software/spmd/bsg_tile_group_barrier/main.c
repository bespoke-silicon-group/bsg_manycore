#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
//#define BSG_BARRIER_DEBUG
#include "bsg_tile_group_barrier.h"

/************************************************************************
 *  Declear an array in DRAM. 
 *  *************************************************************************/
//int data[4] __attribute__ ((section (".dram"))) = { -1, 1, 0xF, 0x80000000};

#define array_size(a)               \
    (sizeof(a)/(sizeof((a)[0])))

volatile int data[bsg_tiles_X][bsg_tiles_Y] __attribute__((section (".dram")));

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int main() {
        int i, j, id;

        bsg_set_tile_x_y();

        id = bsg_x_y_to_id(bsg_x, bsg_y);

        data[bsg_id_to_x(id)][bsg_id_to_y(id)] = id;
      

        bsg_tile_group_barrier(&r_barrier, &c_barrier);

        if (id == 0) {
                for (i = 0; i < array_size(data); i++)
                    for (j = 0; j < array_size(data[i]); j++)
                            bsg_printf("data[%d][%d]=%08x\n", i, j, data[i][j]);  
         }

         bsg_tile_group_barrier(&r_barrier, &c_barrier);


         data[bsg_id_to_x(id)][bsg_id_to_y(id)] = 0;

         bsg_tile_group_barrier(&r_barrier, &c_barrier);

         if (id == 0) {
                   for (i = 0; i < array_size(data); i++)
                           for (j = 0; j < array_size(data[i]); j++)
                                bsg_printf("data[%d][%d]=%d\n", i, j, data[i][j]);

                   bsg_finish();
         }

         bsg_wait_while(1);
}
