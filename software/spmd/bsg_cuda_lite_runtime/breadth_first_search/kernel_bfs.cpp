#include "threading/local_range.h"
#include "threading/num_threads.h"
#include "threading/thread_id.h"
#include "graph_formats/csr_blob.h"
#include "graph_algorithm/csr_setup_graph_data.hpp"

extern "C" {
#include "bsg_manycore.h"
#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"
}

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1)

using namespace formats;

extern "C" int bfs_dense_pull_dense_frontier_in_dense_frontier_out(
    const csr_blob_header_t *CSR,
    int *visited,
    const int *dense_frontier_in,
    int *dense_frontier_out) {

    csr_setup_graph_data(CSR);
    //setup_graph_data(CSR);

    bsg_cuda_print_stat_kernel_start();
    
    int dst_s, dst_e;
    local_range(NODES, &dst_s, &dst_e);

    for (int dst = dst_s; dst < dst_e; dst++) {
        if (visited[dst] == 0) {        
            const int32_t *neigh = B_NEIGH[dst];
            int degree = B_DEGREE[dst];
            for (int i = 0; i < degree; i++) {
                int src = neigh[i];
                if (dense_frontier_in[src]) {
                    dense_frontier_out[dst] = 1;
                    visited[dst] = 1;
                    break;
                }
            }
        }
    }
    
    bsg_tile_group_barrier(&r_barrier, &c_barrier);
    bsg_cuda_print_stat_kernel_end();
    
    return 0;
}

extern "C" int bfs_sparse_push_sparse_frontier_in_dense_frontier_out(
    const csr_blob_header_t *CSR,
    int *visited,
    const int *sparse_frontier_in,
    int *dense_frontier_out) {

    //setup_graph_data(CSR);
    csr_setup_graph_data(CSR);

    bsg_cuda_print_stat_kernel_start();
    for (int i = thread_id(); i < NODES; i += num_threads()) {
        int src = sparse_frontier_in[i];
        if (src == -1) break;

        const int32_t *neigh = F_NEIGH[src];
        int degree = F_DEGREE[src];
        for (int j = 0; j < degree; j++) {
            int dst = neigh[j];
            if (visited[dst] == 0) {
                dense_frontier_out[dst] = 1;
                visited[dst] = 1;
            }
        }            
    }
    
    bsg_tile_group_barrier(&r_barrier, &c_barrier);
    bsg_cuda_print_stat_kernel_end();
    return 0;
}
