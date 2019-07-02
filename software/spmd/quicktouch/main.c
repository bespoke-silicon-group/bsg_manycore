/**
 *  quicktouch
 *
 *  one tile writes some value to the first word of data_mem of all the other tiles,
 *  and validates reading back.
 *  this tile also computes some floating-point multiply-add value and store
 *  in the first word of each vcache, and it reads them back to validate.
 *
 */


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


#define hex(X) (*(int*)&X)


int main()
{
  
  int remote_tile_store_val[bsg_global_X*(bsg_global_Y-1)];
  int remote_tile_load_val[bsg_global_X*(bsg_global_Y-1)];


  for (int x = 0; x < bsg_global_X; x++)
  {
    for (int y = 0; y < bsg_global_Y-1; y++)
    {
      if (x != 0 && y != 0) 
      {
        int id = x+(y*bsg_global_X);
        remote_tile_store_val[id] = 0xdead+x+y;
        bsg_global_store(x, y+1, 0x1000, remote_tile_store_val[id]);
      }
    }
  }
  for (int x = 0; x < bsg_global_X; x++)
  {
    for (int y = 0; y < bsg_global_Y-1; y++)
    {
      if (x != 0 && y != 0) 
      {
        int id = x+(y*bsg_global_X);
        bsg_global_load(x, y+1, 0x1000, remote_tile_load_val[id]);
      }
    }
  }

  for (int x = 0; x < bsg_global_X; x++)
  {
    for (int y = 0; y < bsg_global_Y-1; y++)
    {
      if (x != 0 && y != 0) 
      {
        int id = x+(y*bsg_global_X);
        if (remote_tile_load_val[id] != remote_tile_store_val[id])
          bsg_fail();
      }
    }
  }

  float vcache_store_val[bsg_global_X];
  float vcache_load_val[bsg_global_X];

  for (int x = 0; x < bsg_global_X; x++)
  {
    float a = 1.1;
    float b = (float) x;
    float c = -0.32;
    vcache_store_val[x] = (a*b)+c;
    bsg_global_float_store(x,bsg_global_Y,0,vcache_store_val[x]);
  }


  for (int x = 0; x < bsg_global_X; x++)
  {
    float temp;
    bsg_global_float_load(x,bsg_global_Y,0,temp);
    vcache_load_val[x] =temp;
  }


  for (int x = 0; x < bsg_global_X; x++)
  {
    if (vcache_load_val[x] != vcache_store_val[x])
    {
      bsg_printf("x: %d, expected: %x, actual: %x\n",
        x, hex(vcache_store_val[x]), hex(vcache_load_val[x]));
      bsg_fail();
    }
  }
  bsg_finish();
}

