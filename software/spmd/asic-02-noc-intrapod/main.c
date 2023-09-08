#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int data[bsg_tiles_X*bsg_tiles_Y];

int main()
{
  bsg_set_tile_x_y();
  

  // store;
  for (int y = 0; y < bsg_tiles_Y; y++) {
    for (int x = 0; x < bsg_tiles_X; x++) {
      int *ptr = bsg_remote_ptr(x,y,&data[__bsg_id]);
      int store_val = (x+1)*(y+1); 
      *ptr = store_val;
    }
  }
  bsg_fence();


  // load;
  for (int y = 0; y < bsg_tiles_Y; y++) {
    for (int x = 0; x < bsg_tiles_X; x++) {
      int *ptr = bsg_remote_ptr(x,y,&data[__bsg_id]);
      int load_val = *ptr;
      if (load_val != (x+1)*(y+1)) bsg_fail();
    }
  }

  bsg_finish();

  bsg_wait_while(1);
}

