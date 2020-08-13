#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

bsg_attr_remote int vec1[4] __attribute__ ((section (".dram"))) = {1, 1, 1, 1};
bsg_attr_remote int vec2[4] __attribute__ ((section (".dram"))) = {1, 1, 1, 1};

void vec_add(bsg_attr_remote int* bsg_attr_noalias A,
             bsg_attr_remote int* bsg_attr_noalias B,
             int N) {
  bsg_unroll(4)
  for(int i = 0; i < N; ++i)
    A[i] += B[i];
}

int main() {
  bsg_set_tile_x_y();

  if(__bsg_id == 0) {
    vec_add(vec1, vec2, 4);

    for(int i = 0; i < 4; ++i) {
      if(vec1[i] != 2)
        bsg_fail();
    }

    bsg_finish();
  }

  bsg_wait_while(1);
}
