#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int data[bsg_global_Y*bsg_global_X];

int main()
{
  bsg_set_tile_x_y();

  // store zero;
  for (int py = 0; py < bsg_pods_Y; py++) {
    for (int px = 0; px < bsg_pods_X; px++) {
      for (int y = 0; y < bsg_global_Y; y++) {
        for (int x = 0; x < bsg_global_X; x++) {
          int store_val = 0;
          bsg_remote_int_ptr ptr = bsg_global_pod_ptr(px,py,x,y,&data[__bsg_id]);
          *ptr = store_val;
        }
      }
    }
  }
  bsg_fence();


  // load;
  for (int py = 0; py < bsg_pods_Y; py++) {
    for (int px = 0; px < bsg_pods_X; px++) {
      for (int y = 0; y < bsg_global_Y; y++) {
        for (int x = 0; x < bsg_global_X; x++) {
          bsg_remote_int_ptr ptr = bsg_global_pod_ptr(px,py,x,y,&data[__bsg_id]);
          int load_val = *ptr;
          if (load_val != 0) bsg_fail();
        }
      }
    }
  }
  

  // store;
  for (int py = 0; py < bsg_pods_Y; py++) {
    for (int px = 0; px < bsg_pods_X; px++) {
      for (int y = 0; y < bsg_global_Y; y++) {
        for (int x = 0; x < bsg_global_X; x++) {
          int store_val = (py+1)*(px+1)*(y+1)*(x+1)*(__bsg_id+1);
          bsg_remote_int_ptr ptr = bsg_global_pod_ptr(px,py,x,y,&data[__bsg_id]);
          *ptr = store_val;
        }
      }
    }
  }
  bsg_fence();


  // load;
  for (int py = 0; py < bsg_pods_Y; py++) {
    for (int px = 0; px < bsg_pods_X; px++) {
      for (int y = 0; y < bsg_global_Y; y++) {
        for (int x = 0; x < bsg_global_X; x++) {
          bsg_remote_int_ptr ptr = bsg_global_pod_ptr(px,py,x,y,&data[__bsg_id]);
          int load_val = *ptr;
          if (load_val != (py+1)*(px+1)*(y+1)*(x+1)*(__bsg_id+1)) bsg_fail();
        }
      }
    }
  }

  bsg_finish();
  bsg_wait_while(1);
}

