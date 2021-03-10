#include <bsg_set_tile_x_y.h>
#include <bsg_manycore.h>
#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include <bsg_tile_group_barrier.h>

#define ARRAY_SIZE (128*1024)
#define dram_data __attribute__((section(".dram")))

static dram_data bsg_attr_remote float A[ARRAY_SIZE];
static dram_data bsg_attr_remote float B[ARRAY_SIZE];
static dram_data bsg_attr_remote float C[ARRAY_SIZE];
static dram_data bsg_attr_remote float D[ARRAY_SIZE];

INIT_TILE_GROUP_BARRIER(rbar, cbar, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int stream_read(bsg_attr_remote float *__restrict  A, int n, int id, int nids);
int stream_write(bsg_attr_remote float *__restrict A, int n, int id, int nids);
int stream_copy(bsg_attr_remote float *__restrict  A, bsg_attr_remote float *__restrict B, int n, int id, int nids);

#define STREAM_READ
//#define STREAM_WRITE
//#define STREAM_COPY

int main()
{
    bsg_set_tile_x_y();
    bsg_cuda_print_stat_kernel_start();
#ifdef STREAM_READ
    bsg_tile_group_barrier(&rbar, &cbar);
    stream_read( A,     ARRAY_SIZE, __bsg_id, bsg_tiles_X * bsg_tiles_Y);
#endif
#ifdef STREAM_WRITE
    bsg_tile_group_barrier(&rbar, &cbar);
    stream_write(B,     ARRAY_SIZE, __bsg_id, bsg_tiles_X * bsg_tiles_Y);
#endif
#ifdef STREAM_COPY
    bsg_tile_group_barrier(&rbar, &cbar);
    stream_copy( D, C,  ARRAY_SIZE, __bsg_id, bsg_tiles_X * bsg_tiles_Y);
#endif
    bsg_cuda_print_stat_kernel_end();
    bsg_tile_group_barrier(&rbar, &cbar);
    bsg_finish();
}
