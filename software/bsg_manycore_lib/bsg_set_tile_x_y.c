
#include "bsg_manycore.h"

// these are private variables
// we do not make them volatile
// so that they may be cached

int __bsg_x = -1;
int __bsg_y = -1;
int __bsg_id = -1;
int __bsg_grp_org_x = -1;
int __bsg_grp_org_y = -1;
int __bsg_grid_dim_x = -1;
int __bsg_grid_dim_y = -1;
int __bsg_tile_group_id_x = -1;
int __bsg_tile_group_id_y = -1;
int __bsg_tile_group_id = -1;

void bsg_set_tile_x_y()
{
  volatile int *bsg_x_v = &__bsg_x;
  volatile int *bsg_y_v = &__bsg_y;

  bsg_remote_int_ptr grp_org_x_p;
  bsg_remote_int_ptr grp_org_y_p;

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

  grp_org_x_p = bsg_remote_ptr_control( __bsg_x, __bsg_y, CSR_TGO_X );
  grp_org_y_p = bsg_remote_ptr_control( __bsg_x, __bsg_y, CSR_TGO_Y );

  __bsg_grp_org_x  = * grp_org_x_p;
  __bsg_grp_org_y  = * grp_org_y_p;
  __bsg_id = __bsg_y * bsg_tiles_X + __bsg_x;
  __bsg_grid_dim_x = 1;
  __bsg_grid_dim_y = 1;
  __bsg_tile_group_id_x = 0;
  __bsg_tile_group_id_y = 0;
  __bsg_tile_group_id = 0;
}
