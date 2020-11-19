#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

#define WRITE_N 1024
#define N 512

int data1[2 * WRITE_N * bsg_tiles_X * bsg_tiles_Y] __attribute__ ((section (".dram"))) = {0};

int main()
{
  bsg_set_tile_x_y();

  // create a 1024KB int array
  int start = __bsg_id * WRITE_N;
  for (int i = start; i < start + WRITE_N; i++)
  {
    data1[i] = 42;
  }

  // write the second half
  start += WRITE_N * bsg_tiles_X * bsg_tiles_Y;
  for (int i = start; i < start + WRITE_N; i++)
  {
    data1[i] = 43;
  }

  bsg_fence();

  int buf[N];

  // read first 256KB, which hopefully wont have much in L2
  start = __bsg_id * N;

  for (int iter = 1; iter < 4; iter++) {

    bsg_cuda_print_stat_start(iter);
    //bsg_fence();

    int buf_offset = 0;
    for (int idx = start; idx < start + N; idx++) {
      buf[buf_offset] = data1[idx];
      buf_offset++;
    }

    bsg_cuda_print_stat_end(iter);
    //bsg_fence();

    buf_offset = 0;

    int acc = 0;
    for (buf_offset = 0; buf_offset < N; buf_offset++) {
      acc += buf[buf_offset];
    }
    if (acc != 42 * N) bsg_fail();
  }

  bsg_tile_group_barrier(&r_barrier, &c_barrier);
  bsg_finish();
  bsg_wait_while(1);
}

