
/*!
 * This kernel performs softmax 
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "math.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y

#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X - 1, 0, bsg_tiles_Y - 1);

__attribute__((noinline))
int kernel_softmax(int *A, int *B, int M, int N, int block_size_y, int block_size_x)
{
        bsg_tile_group_shared_mem(float, sums, bsg_tiles_X * bsg_tiles_Y);

        int start_y = __bsg_tile_group_id_y * block_size_y;
        int start_x = __bsg_tile_group_id_x * block_size_x;
        int end_y = start_y + block_size_y;
        int end_x = start_x + block_size_x;

        // Compute B = exp(A)
        for(int y = start_y + __bsg_y; y < end_y; y += bsg_tiles_Y)
        {
                for(int x = start_x + __bsg_x; x < end_x; x += bsg_tiles_X)
                {
                        B[y * N + x] = expf(A[y * N + x]);
                }
        }
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        // Compute sum(B) for each element belonging to a tile in the tilegroup
        for(int y = start_y + __bsg_y; y < end_y; y += bsg_tiles_Y)
        {
                for(int x = start_x + __bsg_x; x < end_x; x += bsg_tiles_X)
                {
                        sums[__bsg_y * bsg_tiles_X + __bsg_x] += B[y * N + x];
                }
        }
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        // Compute sum of the columns of the sum matrix
        if(__bsg_y == 0)
        {
                for(int y = 1; y < bsg_tiles_Y; y++)
                {
                        sums[__bsg_x] += sums[y * bsg_tiles_X + __bsg_x];
                }
        }
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        // Compute sum of row 0 of the row matrix
        if(__bsg_y == 0 && __bsg_x == 0)
        {
                for(int x = 1; x < bsg_tiles_X; x++)
                {
                        sums[0] += sums[x];
                }
        }
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        // sum(B) is now stored in sums[0], so we divide everything by sums[0]
        for(int y = start_y + __bsg_y; y < end_y; y += bsg_tiles_Y)
        {
                for(int x = start_x + __bsg_x; x < end_x; x += bsg_tiles_X)
                {
                        B[y * N + x] /= sums[0];
                }
        }
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        return 0;
}
