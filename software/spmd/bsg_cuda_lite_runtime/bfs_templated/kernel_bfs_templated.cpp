#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
#include <math.h>
#include <local_range.h>

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);
//__attribute__((section(".dram"))) int  * __restrict parent;


void get_block_id(int n, int * block_id)
{
	*block_id = bsg_id % n;
} 

__attribute__((section(".dram"))) int ctr = 0;
template <typename TO_FUNC , typename APPLY_FUNC> int edgeset_apply_push_serial_from_vertexset_to_filter_func_with_frontier(int *out_indices, int*out_neighbors, int *frontier, int *next_frontier, int *parent, TO_FUNC to_func, APPLY_FUNC apply_func, int V, int E, int block_size_x)
{
  int start, end, block_id;
  int blocks = (int) ceil(V / block_size_x);
  local_range(V, &start, &end);
  int start_x = block_size_x * (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x);
  for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) {
  //for (int iter_x = start; iter_x < end; iter_x++) {
    if (iter_x < V-1) {  //in bounds (and not last)
       if(frontier[iter_x]) { //in frontier
          for(int iter_n = out_indices[start_x + iter_x]; iter_n < out_indices[start_x + iter_x + 1]; iter_n++) {
            if (to_func(out_neighbors[iter_n], parent)) {
              if( apply_func ( iter_x , out_neighbors[iter_n], parent  ) ) {
                next_frontier[out_neighbors[iter_n]] = 1;
              }
            }
          }
        }

    }
    else if ((start_x + iter_x) == V-1) {
      if(frontier[iter_x]) {
        for(int iter_n = out_indices[iter_x]; iter_n < E; iter_n++) {
          if(to_func(out_neighbors[iter_n], parent)) {
            if( apply_func ( (iter_x) , out_neighbors[iter_n], parent  ) ) {
              next_frontier[out_neighbors[iter_n]] = 1;
            }
          }
        }
      }
    }
  }

  bsg_tile_group_barrier(&r_barrier, &c_barrier);
  return 0;
} //end of edgeset apply function


struct parent_generated_vector_op_apply_func_0
{
  void operator() (int v, int *parent)
  {
    parent[v] =  -(1) ;
  };
};
struct updateEdge
{
  bool operator() (int src, int dst, int *parent)
  {
    bool output1 ;
    parent[dst] = src;
    output1 = (bool) 1;
    return output1;
  };
};
struct toFilter
{
  bool operator() (int v, int *parent)
  {
    bool output ;
    output = (parent[v]) == ( -(1) );
    return output;
  };
};
struct reset
{
  void operator() (int v, int *parent)
  {
    parent[v] =  -(1) ;
  };
};

extern "C" int  __attribute__ ((noinline)) parent_generated_vector_op_apply_func_0_kernel(int *parent, int V, int E, int block_size_x) {
	int start_x = block_size_x * (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x);
	for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) {
		if ((start_x + iter_x) < V) {
			parent_generated_vector_op_apply_func_0()(start_x + iter_x, parent);
		}
		else {
			break;
		}
	}
	bsg_tile_group_barrier(&r_barrier, &c_barrier);
	return 0;
}
extern "C" int  __attribute__ ((noinline)) reset_kernel(int *parent, int V, int E, int block_size_x) {
	int start_x = block_size_x * (__bsg_tile_group_id_y * __bsg_grid_dim_x + __bsg_tile_group_id_x);
	for (int iter_x = __bsg_id; iter_x < block_size_x; iter_x += bsg_tiles_X * bsg_tiles_Y) {
		if ((start_x + iter_x) < V) {
			reset()(start_x + iter_x, parent);
		}
		else {
			break;
		}
	}
	bsg_tile_group_barrier(&r_barrier, &c_barrier);
	return 0;
}
extern "C" int __attribute__ ((noinline)) edgeset_apply_push_serial_from_vertexset_to_filter_func_with_frontier_call(int *out_indices, int*out_neighbors, int *frontier, int *next_frontier, int *parent, int V, int E, int block_size_x) {
        bsg_print_stat(ctr);
	ctr++;
	edgeset_apply_push_serial_from_vertexset_to_filter_func_with_frontier(out_indices, out_neighbors, frontier, next_frontier, parent,  toFilter(), updateEdge(), V, E, block_size_x);
        bsg_print_stat(ctr);
	ctr++;
	edgeset_apply_push_serial_from_vertexset_to_filter_func_with_frontier(out_indices, out_neighbors, frontier, next_frontier, parent,  toFilter(), updateEdge(), V, E, block_size_x);
	return 0;
}
