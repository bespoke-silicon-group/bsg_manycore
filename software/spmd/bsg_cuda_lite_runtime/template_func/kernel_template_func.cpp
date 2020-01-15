#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"


#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

__attribute__((section(".dram"))) int test_val;

template <typename Func> void  __attribute__ ((noinline)) kernel_template_func_test(Func f) {
  f(5);
}

struct test
{
  void operator()(int val){
    test_val = val;
  };
};

extern "C" int __attribute__ ((noinline)) kernel_template_func(int block_size_x) {
  bsg_print_stat(1);
  int start_x = block_size_x * (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x);
  if(start_x == 0) {
    kernel_template_func_test(test());
  }
  bsg_tile_group_barrier(&r_barrier, &c_barrier);
  bsg_print_stat(2);
  return 0;
}
