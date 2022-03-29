//This kernel adds 2 vectors

#define Index3D(_nx,_ny,_i,_j,_k) ((_i)+_nx*((_j)+_ny*(_k)))
#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include <math.h>
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_group_strider.hpp"
#include "bsg_cuda_lite_barrier.h"

// copy 64 elements along X axis
void copyXAxis64(float* src, float* dst) {
  for (int i = 0; i < 4; i++) {
    float tmp00 =  src[0];
    float tmp01 =  src[1];
    float tmp02 =  src[2];
    float tmp03 =  src[3];
    float tmp04 =  src[4];
    float tmp05 =  src[5];
    float tmp06 =  src[6];
    float tmp07 =  src[7];
    float tmp08 =  src[8];
    float tmp09 =  src[9];
    float tmp10 = src[10];
    float tmp11 = src[11];
    float tmp12 = src[12];
    float tmp13 = src[13];
    float tmp14 = src[14];
    float tmp15 = src[15];
    asm volatile("": : :"memory");
     dst[0] = tmp00;
     dst[1] = tmp01;
     dst[2] = tmp02;
     dst[3] = tmp03;
     dst[4] = tmp04;
     dst[5] = tmp05;
     dst[6] = tmp06;
     dst[7] = tmp07;
     dst[8] = tmp08;
     dst[9] = tmp09;
    dst[10] = tmp10;
    dst[11] = tmp11;
    dst[12] = tmp12;
    dst[13] = tmp13;
    dst[14] = tmp14;
    dst[15] = tmp15;
    dst += 16;
    src += 16;
  }
  return;
}

extern "C" __attribute__ ((noinline))
int kernel_jacobi(int c0, int c1, float *A0, float * Anext,
                  const int nx, const int ny, const int nz) {

  bsg_barrier_hw_tile_group_init();
  bsg_fence();
  bsg_barrier_hw_tile_group_sync();
  bsg_cuda_print_stat_kernel_start();

  // Calculate 2D XY distribution. One output per tile (temp).
  const int j = __bsg_x + 1;
  const int k = __bsg_y + 1;
  // Idea - unroll Z-axis (k). By 64, which is the input size

  // Check if additional load from DRAM is necessary
  const bool x_l_bound = (__bsg_x == 0);
  const bool x_h_bound = (__bsg_x == (bsg_tiles_X-1));
  const bool y_l_bound = (__bsg_y == 0);
  const bool y_h_bound = (__bsg_y == (bsg_tiles_Y-1));

  // Buffer for A0
  float a_self[64] = {0.0f};

  // Auxillary buffers
  float aux_left[64];
  float aux_right[64];
  float aux_up[64];
  float aux_down[64];

  // Construct remote pointers
  float* a_up, *a_down, *a_left, *a_right;

  if (x_l_bound) {
    a_left = aux_left;
  } else {
    bsg_tile_group_strider<BSG_TILE_GROUP_X_DIM, 0, BSG_TILE_GROUP_Y_DIM, 0, float> r_left(a_self,  __bsg_x-1, __bsg_y);
    a_left = r_left.ptr;
  }
  if (x_h_bound) {
    a_right = aux_right;
  } else {
    bsg_tile_group_strider<BSG_TILE_GROUP_X_DIM, 0, BSG_TILE_GROUP_Y_DIM, 0, float> r_right(a_self,  __bsg_x+1, __bsg_y);
    a_right = r_right.ptr;
  }
  if (y_l_bound) {
    a_up = aux_up;
  } else {
    bsg_tile_group_strider<BSG_TILE_GROUP_X_DIM, 0, BSG_TILE_GROUP_Y_DIM, 0, float> r_up(a_self,  __bsg_x, __bsg_y-1);
    a_up = r_up.ptr;
  }
  if (y_h_bound) {
    a_down = aux_down;
  } else {
    bsg_tile_group_strider<BSG_TILE_GROUP_X_DIM, 0, BSG_TILE_GROUP_Y_DIM, 0, float> r_down(a_self,  __bsg_x, __bsg_y+1);
    a_down = r_down.ptr;
  }

  for (int ii = 1; ii < nx-1; ii += 62) {

    // Inital load -- we load 64 and produce 62
    if (x_l_bound) {
      copyXAxis64(&(A0[Index3D (nx, ny, ii-1, j-1, k)]), a_left);
    }
    if (x_h_bound) {
      copyXAxis64(&(A0[Index3D (nx, ny, ii-1, j+1, k)]), a_right);
    }
    if (y_l_bound) {
      copyXAxis64(&(A0[Index3D (nx, ny, ii-1, j, k-1)]), a_up);
    }
    if (y_h_bound) {
      copyXAxis64(&(A0[Index3D (nx, ny, ii-1, j, k+1)]), a_down);
    }

    copyXAxis64(&(A0[Index3D (nx, ny, ii-1, j, k)]), a_self);
    bsg_barrier_hw_tile_group_sync();

    bsg_unroll(8)
    for (int i = 1; i < 63; i++) {
      // Load top
      // top = A0[Index3D (nx, ny, i+1, j, k)];
      float    top = a_self[i+1];
      float bottom = a_self[i-1];

      float left  = a_left[i];
      float right = a_right[i];
      float    up = a_up[i];
      float  down = a_down[i];

      // Jacobi
      float next = (top + bottom + left + right + up + down) * c1 - a_self[i] * c0;
      Anext[Index3D (nx, ny, ii-1+i, j, k)] = next;
    }
    bsg_barrier_hw_tile_group_sync();
  }

  bsg_cuda_print_stat_kernel_end();
  bsg_fence();
  bsg_barrier_hw_tile_group_sync();

	return 0;
}
