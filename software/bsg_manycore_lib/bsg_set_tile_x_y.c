
#include "bsg_manycore.h"

// these are private variables
// we do not make them volatile
// so that they may be cached

int bsg_x = -1;
int bsg_y = -1;

void bsg_set_tile_x_y()
{
  volatile int *bsg_x_v = &bsg_x;
  volatile int *bsg_y_v = &bsg_y;

  // everybody stores to tile 0,0
  bsg_remote_store(0,0,bsg_x_v,0);
  bsg_remote_store(0,0,bsg_y_v,0);

  bsg_wait_while(*bsg_x_v < 0);
  bsg_wait_while(*bsg_y_v < 0);

  if (!*bsg_x_v && !*bsg_y_v)
    for (int x = 0; x < bsg_tiles_X; x++)
      for (int y = 0; y < bsg_tiles_Y; y++)
      {
        bsg_remote_store(x,y,bsg_x_v,x);
        bsg_remote_store(x,y,bsg_y_v,y);
      }
}
