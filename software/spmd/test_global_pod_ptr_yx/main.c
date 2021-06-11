// store and load from every tile in the entire pod array using bsg_global_pod_ptr;


#include "bsg_manycore.h"
#include "bsg_manycore_arch.h"
#include "bsg_set_tile_x_y.h"


volatile int data;


void test_pod(int px, int py)
{
  volatile int* pod_addr[bsg_global_X][bsg_global_Y];

  // store
  for (int x = 0; x < bsg_global_X; x++) {
    for (int y = 0; y < bsg_global_Y; y++) {
      volatile int* ptr = bsg_global_pod_ptr(px,py,x,y,&data);
      pod_addr[x][y] = ptr;
      *ptr = (int) ptr;
    }
  }

  // load
  for (int x = 0; x < bsg_global_X; x++) {
    for (int y = 0; y < bsg_global_Y/8; y++) {
      register int* load_val[8];
      int curr_y = 8*y;
      load_val[0] = (int*) *pod_addr[x][curr_y++];
      load_val[1] = (int*) *pod_addr[x][curr_y++];
      load_val[2] = (int*) *pod_addr[x][curr_y++];
      load_val[3] = (int*) *pod_addr[x][curr_y++];
      load_val[4] = (int*) *pod_addr[x][curr_y++];
      load_val[5] = (int*) *pod_addr[x][curr_y++];
      load_val[6] = (int*) *pod_addr[x][curr_y++];
      load_val[7] = (int*) *pod_addr[x][curr_y++];

      curr_y = 8*y;
      if (load_val[0] != pod_addr[x][curr_y++]) bsg_fail();
      if (load_val[1] != pod_addr[x][curr_y++]) bsg_fail();
      if (load_val[2] != pod_addr[x][curr_y++]) bsg_fail();
      if (load_val[3] != pod_addr[x][curr_y++]) bsg_fail();
      if (load_val[4] != pod_addr[x][curr_y++]) bsg_fail();
      if (load_val[5] != pod_addr[x][curr_y++]) bsg_fail();
      if (load_val[6] != pod_addr[x][curr_y++]) bsg_fail();
      if (load_val[7] != pod_addr[x][curr_y++]) bsg_fail();
    }
  }
}



int main()
{
  bsg_set_tile_x_y();

  for (int px = 0; px < num_pods_X; px++) {
    for (int py = 0; py < num_pods_Y; py++) {
      test_pod(px,py);
    }
  }


  bsg_finish();
  bsg_wait_while(1);
}

