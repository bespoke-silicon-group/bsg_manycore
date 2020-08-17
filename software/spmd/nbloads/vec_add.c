#include "bsg_manycore.h"

void vec_add(bsg_attr_remote int* bsg_attr_noalias A,
             bsg_attr_remote int* bsg_attr_noalias B,
             int N) {
  bsg_unroll(4)
  for(int i = 0; i < N; ++i)
    A[i] += B[i];
}
