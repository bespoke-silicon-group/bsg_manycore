#include "bsg_manycore.h"

#include <stdint.h>

// Manycore Tesnor
typedef struct {
  uint32_t N;
  uint32_t dims;
  uint32_t* strides;
  float* data;
} bsg_tensor_t;

inline void bsg_tensor_print_flat(const bsg_tensor_t* t) {
  for(int i=0; i < t->N; ++i) {
    if(i) bsg_printf(", ");

    bsg_printf("%x", t->data[i]);
  }

  bsg_putchar('\n');
}
