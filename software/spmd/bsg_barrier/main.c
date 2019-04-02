#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_mutex.h"
#include "bsg_barrier.h"
//---------------------------------------------------------

#define BARRIER_X 0
#define BARRIER_Y 0

#define BARRIER_X_END (bsg_tiles_X - 1)
#define BARRIER_Y_END (bsg_tiles_Y - 1)
#define BARRIER_TILES ( (BARRIER_X_END +1) * ( BARRIER_Y_END+1) )

bsg_barrier     tile0_barrier = BSG_BARRIER_INIT(0, BARRIER_X_END, 0, BARRIER_Y_END);

#define array_size(a)               \
    (sizeof(a)/(sizeof((a)[0])))

volatile int data[bsg_tiles_X][bsg_tiles_Y] __attribute__((section (".dram")));

////////////////////////////////////////////////////////////////////
int main() {
        int i, j, id;

        bsg_set_tile_x_y();

        id = bsg_x_y_to_id(bsg_x, bsg_y);

        data[bsg_id_to_x(id)][bsg_id_to_y(id)] = id;
        
        if( bsg_x == 0  && bsg_y == 0) { bsg_print_time(); } 
        bsg_barrier_wait( &tile0_barrier, 0, 0);
        if( bsg_x == 0  && bsg_y == 0) { bsg_print_time(); } 

        if (id == 0) {
                for (i = 0; i < array_size(data); i++)
                    for (j = 0; j < array_size(data[i]); j++)
                            bsg_printf("data[%d][%d]=%08x\n", i, j, data[i][j]);  
         }

        bsg_barrier_wait( &tile0_barrier, 0, 0);

        data[bsg_id_to_x(id)][bsg_id_to_y(id)] = 0;

        bsg_barrier_wait( &tile0_barrier, 0, 0);

         if (id == 0) {
                   for (i = 0; i < array_size(data); i++)
                           for (j = 0; j < array_size(data[i]); j++)
                                bsg_printf("data[%d][%d]=%d\n", i, j, data[i][j]);

                   bsg_finish();
         }

         bsg_wait_while(1);
}

