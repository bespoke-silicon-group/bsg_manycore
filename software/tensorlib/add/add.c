#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tensor.h"

int __attribute__ ((noinline)) add(
    bsg_tensor_t* res, 
    bsg_tensor_t* a, 
    bsg_tensor_t* b,
    float* alpha) {
  if(__bsg_id == 0) {
    for(uint32_t i=0; i < res->N; ++i) {
      res->data[i] = a->data[i] + (*alpha) * b->data[i];
    }

    return 0;
  } else {
    bsg_wait_while(1);
  }
}
