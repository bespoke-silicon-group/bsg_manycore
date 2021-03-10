#include <bsg_set_tile_x_y.h>
#include <bsg_manycore.h>
#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include <bsg_tile_group_barrier.h>

#define A_n_per_core (1024)
#define A_SIZE (A_n_per_core * bsg_tiles_X * bsg_tiles_Y)
#define G_SIZE (1024*1024*1024)

#define dram_data __attribute__((section(".dram")))

//static dram_data bsg_attr_remote int G[G_SIZE];
static dram_data bsg_attr_remote int G[1];

INIT_TILE_GROUP_BARRIER(rbar, cbar, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

void gups_init(bsg_attr_remote int *__restrict G,
               int *__restrict A)
{
    int x = 0xdeadbeef ^ (bsg_id << 17);
    for (int i = 0; i < A_n_per_core; ++i) {
        x ^= x << 11;
        x ^= x >> 5;
        x ^= x << 15;
        A[i] = x & (G_SIZE-1);
    }

    return;
}

int gups(bsg_attr_remote int *__restrict G, int *__restrict A, int n);

int main()
{
    bsg_set_tile_x_y();

    int A[A_n_per_core];
    gups_init(G, A);

    bsg_tile_group_barrier(&rbar, &cbar);
    bsg_cuda_print_stat_kernel_start();

    gups(G, A, A_n_per_core);

    bsg_tile_group_barrier(&rbar, &cbar);
    bsg_cuda_print_stat_kernel_end();

    bsg_finish();
}
