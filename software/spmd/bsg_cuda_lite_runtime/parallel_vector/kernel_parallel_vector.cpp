//This kernel modifies 2 global scalar variables

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

void local_range(int n, int *start, int *end)
{
        int sz = n / (bsg_tiles_X * bsg_tiles_Y);
        *start = bsg_id * sz;
        *end = *start + sz;
        *end = *end < n ? *end : n;
}

void get_block_id(int n, int * id)
{
       *id = bsg_id % n;
}

extern "C" int  __attribute__ ((noinline)) kernel_parallel_vector(int * test, int V, int block_size_x) {
	int start, end, block_id;
	local_range(V, &start, &end);
        int blocks = (int) ceil(V/block_size_x);
        get_block_id(blocks, &block_id);
        
        //int start_x = block_size_x * (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x);
        //for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) {
        for (int iter_x = 0; iter_x < V; iter_x++){
          int curr_idx = block_size_x * block_id + iter_x;       
          test[V*block_id + iter_x] = iter_x;
        }

        bsg_tile_group_barrier(&r_barrier, &c_barrier);

  return 0;
}
