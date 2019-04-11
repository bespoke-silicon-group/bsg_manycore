#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y


int main() {
        int id;

        bsg_set_tile_x_y();

        id = bsg_x_y_to_id(bsg_x, bsg_y);

         if (id == 0) {
           bsg_finish();
         }

         bsg_wait_while(1);
}
