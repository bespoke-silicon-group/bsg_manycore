// store and load from every tile in the entire pod array using bsg_global_pod_ptr;


#include "bsg_manycore.h"
#include "bsg_manycore_arch.h"
#include "bsg_set_tile_x_y.h"


volatile int data;


void test_pod(int px, int py)
{
  volatile int* pod_addr[2][bsg_global_X];

  // testing only the first and the last row of the pod.
  int ys[2] = {0,bsg_global_Y-1};

  // store
  for (int y_idx = 0; y_idx < 2; y_idx++) {
    int y = ys[y_idx];
    for (int x = 0; x < bsg_global_X; x++) {
      volatile int* ptr = bsg_global_pod_ptr(px,py,x,y,&data);
      pod_addr[y_idx][x] = ptr;
      *ptr = (int) ptr;
    }
  }

  // load
  for (int y_idx = 0; y_idx < 2; y_idx++) {
    int y = ys[y_idx];
    for (int x = 0; x < bsg_global_X/8; x++) {
      register int* load_val[8];
      int curr_x = 8*x;
      load_val[0] = (int*) *pod_addr[y_idx][curr_x++];
      load_val[1] = (int*) *pod_addr[y_idx][curr_x++];
      load_val[2] = (int*) *pod_addr[y_idx][curr_x++];
      load_val[3] = (int*) *pod_addr[y_idx][curr_x++];
      load_val[4] = (int*) *pod_addr[y_idx][curr_x++];
      load_val[5] = (int*) *pod_addr[y_idx][curr_x++];
      load_val[6] = (int*) *pod_addr[y_idx][curr_x++];
      load_val[7] = (int*) *pod_addr[y_idx][curr_x++];

      curr_x = 8*x;
      if (load_val[0] != pod_addr[y_idx][curr_x++]) bsg_fail();
      if (load_val[1] != pod_addr[y_idx][curr_x++]) bsg_fail();
      if (load_val[2] != pod_addr[y_idx][curr_x++]) bsg_fail();
      if (load_val[3] != pod_addr[y_idx][curr_x++]) bsg_fail();
      if (load_val[4] != pod_addr[y_idx][curr_x++]) bsg_fail();
      if (load_val[5] != pod_addr[y_idx][curr_x++]) bsg_fail();
      if (load_val[6] != pod_addr[y_idx][curr_x++]) bsg_fail();
      if (load_val[7] != pod_addr[y_idx][curr_x++]) bsg_fail();
    }
  }
}



int main()
{
  int i = 0;
  for (int px = 0; px < num_pods_X; px++) {
    for (int py = 0; py < num_pods_Y; py++) {
      test_pod(px,py);
      bsg_print_int(i++);
    }
  }


  bsg_finish();
  bsg_wait_while(1);
}

