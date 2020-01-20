
/*!
  Takes an MxN matrix A and an HxW filter, padding P, vertical stride Sy,
  and horizontal stride Sx. Performs a 2D convolution and outputs into a
  matrix B. 
*/

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "math.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y

#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X - 1, 0, bsg_tiles_Y - 1);

int output_dim(int N, int F, int P, int S)
{
        return 1 + (N - F + 2 * P) / S;
}

__attribute__((noinline))
int kernel_conv2d(const float *A,
                  const int M,
                  const int N,
                  const float *filter,
                  const int H,
                  const int W,
                  const int P,
                  float *B,
                  const int Sy,
                  const int Sx)
{
        int result_h = output_dim(M, H, P, Sy);
        int result_w = output_dim(N, W, P, Sx);

        for(int by = __bsg_y; by < result_h; by += bsg_tiles_Y)
                for(int bx = __bsg_x; bx < result_w; bx += bsg_tiles_X)
                {
                        int window_y = by * Sy;
                        int window_x = bx * Sx;
                        
                        float res = 0;
                        for(int fy = 0; fy < H; fy++)
                                for(int fx = 0; fx < W; fx++)
                                {
                                        int ay = window_y - P + fy;
                                        int ax = window_x - P + fx;
                                        float a = 0;
                                        
                                        if((0 <= ay && ay < M) &&
                                           (0 <= ax && ax < N))
                                                a = A[ay * N + ax];
                                        res += filter[fy * W + fx] * a;
                                }
                        B[by * result_w + bx] = res;
                }

        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        return 0;
}
