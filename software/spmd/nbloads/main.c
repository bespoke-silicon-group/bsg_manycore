/**
 * Sanity test to verify non-blocking load keywords:
 *
 *   - bsg_attr_remote : Declares pointers as remote pointers.
 *   - bsg_attr_noalias: Hints compiler that data pointed by the pointer
 *                       will not be aliased by other pointers within the
 *                       pointer's scope.
 *   - bsg_unroll      : Applies compiler specific unroll pragma.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

bsg_attr_remote int vec1[4] __attribute__ ((section (".dram"))) = {1, 1, 1, 1};
bsg_attr_remote int vec2[4] __attribute__ ((section (".dram"))) = {1, 1, 1, 1};

void vec_add(bsg_attr_remote int* bsg_attr_noalias A,
             bsg_attr_remote int* bsg_attr_noalias B,
             int N);

void vec_sub(bsg_attr_remote int* bsg_attr_noalias A,
             bsg_attr_remote int* bsg_attr_noalias B,
             int N);

int main() {
  bsg_set_tile_x_y();

  if(__bsg_id == 0) {
    vec_sub(vec1, vec2, 4);

    for(int i = 0; i < 4; ++i) {
      if(vec1[i] != 0)
        bsg_fail();
    }

    vec_add(vec1, vec2, 4);

    for(int i = 0; i < 4; ++i) {
      if(vec1[i] != 1)
        bsg_fail();
    }

    bsg_finish();
  }

  bsg_wait_while(1);
}
