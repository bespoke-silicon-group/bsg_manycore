#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tensor.h"

#define xstr(s) str(s)
#define str(s) #s

static inline float binop(float a, float b, float alpha) {
  if (xstr(OP) == "add")
    return a + b * alpha;
  else if (xstr(OP) == "sub")
    return a - b * alpha;
  else if (xstr(OP) == "mul")
    return a * b;
  else if (xstr(OP) == "div")
    return a / b;
  else
    bsg_fail();
}

#undef str
#undef xstr

int __attribute__ ((noinline)) OP(
    bsg_tensor_t* res, 
    bsg_tensor_t* a, 
    bsg_tensor_t* b,
    float* alpha) {
  if(__bsg_id == 0) {
    for(uint32_t i=0; i < res->N; ++i) {
      res->data[i] = binop(a->data[i], b->data[i], *alpha);
    }

    return 0;
  } else {
    bsg_wait_while(1);
  }
}
