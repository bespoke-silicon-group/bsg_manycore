// store and load from every tile in the entire pod array using bsg_global_pod_ptr;


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


volatile int data;


void test_pod(int px, int py)
{
  int load_val[bsg_global_X*bsg_global_Y];
  int store_val[bsg_global_X*bsg_global_Y];

  // store
  for (int x = 0; x < bsg_global_X; x++) {
    for (int y = 0; y < bsg_global_Y; y++) {
      int id = x + (y*bsg_global_X);
      store_val[id] = (px+(py*3)+x)-(y*2); // some hash val
      bsg_global_pod_store(px,py,x,y,&data,store_val[id]);
    }
  }

  // load
  for (int x = 0; x < bsg_global_X; x++) {
    for (int y = 0; y < bsg_global_Y; y++) {
      int id = x + (y*bsg_global_X);
      bsg_global_pod_load(px,py,x,y,&data,load_val[id]);
    }
  }

  // validate
  for (int i = 0; i < bsg_global_X*bsg_global_Y; i++) {
    if (store_val[i] != load_val[i]) {
      bsg_fail();
      bsg_wait_while(1);
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

