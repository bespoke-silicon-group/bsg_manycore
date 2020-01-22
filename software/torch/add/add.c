#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

typedef struct {
  uint32_t N;
  uint32_t* strides;
  float* data;
} hb_mc_tensor_t;

int __attribute__ ((noinline)) add(
    hb_mc_tensor_t* res, hb_mc_tensor_t* a, hb_mc_tensor_t* b,
    float* alpha) {
  if(__bsg_id == 0) {
    for(uint32_t i=0; i < res->N; ++i)
      res->data[i] = a->data[i] + (*alpha) * b->data[i];

    return 0;
  } else {
    bsg_wait_while(1);
  }
}
