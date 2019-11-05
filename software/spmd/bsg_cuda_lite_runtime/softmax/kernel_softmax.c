
/*!
 * This kernel computes Softmax of a matrix A with dimensions MxN and stores the result in B:
 * Softmax(A) = exp(A) / sum(exp(A)) (with division done element-wise).
 * The algorithm works in 3 phases:
 *      1) Compute max by doing a reduction in a shared array, store in variable m
 *      2) Compute sum(exp(A - m)), and store exp(A - m) into B while computing sum
 *      3) Divide every element of B by sum
 */

/*
  Description of reduction:
  If we want to compute an aggregator function F (in this kernel, sum and max), we do it as follows:
        1) Allocate a shared array with one element for each tile in tilegroup
        2) Each tile aggregates elements belonging to it
        3) Tiles in the top row aggregate their column
        4) Tile at (0, 0) aggregates row 0
        At the end, element (0, 0) stores the result of the aggregate.
 */

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "math.h"

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y

#include "bsg_tile_group_barrier.h"

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X - 1, 0, bsg_tiles_Y - 1);

#define max(x, y) (((x) > (y)) ? (x) : (y))

float compute_max(const float *A, float *agg, int M, int N, int block_size_y, int block_size_x)
{
        int start_y = __bsg_tile_group_id_y * block_size_y;
        int start_x = __bsg_tile_group_id_x * block_size_x;
        int end_y = start_y + block_size_y;
        int end_x = start_x + block_size_x;

        float partial_max = -INFINITY;
        // Compute max(B) for each element belonging to a tile in the tilegroup
        for(int y = start_y + __bsg_y; y < end_y; y += bsg_tiles_Y)
        {
                for(int x = start_x + __bsg_x; x < end_x; x += bsg_tiles_X)
                {
                        partial_max = max(A[y * N + x], partial_max);
                }
        }
        bsg_tile_group_shared_store(float, agg, __bsg_y * bsg_tiles_X + __bsg_x, partial_max);
        bsg_tile_group_barrier(&r_barrier, &c_barrier);

        // Compute max of the columns of the aggregator matrix
        if(__bsg_y == 0)
        {
                for(int y = 1; y < bsg_tiles_Y; y++)
                {
                        float other;
                        bsg_tile_group_shared_load(float, agg, y * bsg_tiles_X + __bsg_x, other);
                        partial_max = max(partial_max, other);
                }
                bsg_tile_group_shared_store(float, agg, __bsg_x, partial_max);
        }
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        // Compute max of row 0 of the row matrix
        if(__bsg_y == 0 && __bsg_x == 0)
        {
                for(int x = 1; x < bsg_tiles_X; x++)
                {
                        float other;
                        bsg_tile_group_shared_load(float, agg, x, other);
                        partial_max = max(partial_max, other);
                }
                bsg_tile_group_shared_store(float, agg, 0, partial_max);
        }
        float result;
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        bsg_tile_group_shared_load(float, agg, 0, result);
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        return result;
}

__attribute__((noinline))
int kernel_softmax(const float *A, float *B, int M, int N, int block_size_y, int block_size_x)
{
        // Array for aggregations
        bsg_tile_group_shared_mem(float, agg, bsg_tiles_X * bsg_tiles_Y);
        float m = compute_max(A, agg, M, N, block_size_y, block_size_x);
        int start_y = __bsg_tile_group_id_y * block_size_y;
        int start_x = __bsg_tile_group_id_x * block_size_x;
        int end_y = start_y + block_size_y;
        int end_x = start_x + block_size_x;

        // Compute B = exp(A - m)
        for(int y = start_y + __bsg_y; y < end_y; y += bsg_tiles_Y)
        {
                for(int x = start_x + __bsg_x; x < end_x; x += bsg_tiles_X)
                {
                        B[y * N + x] = expf(A[y * N + x] - m);
                }
        }
        bsg_tile_group_barrier(&r_barrier, &c_barrier);

        float partial_sum = 0;
        // Compute sum(B) for each element belonging to a tile in the tilegroup
        for(int y = start_y + __bsg_y; y < end_y; y += bsg_tiles_Y)
        {
                for(int x = start_x + __bsg_x; x < end_x; x += bsg_tiles_X)
                {
                        partial_sum += B[y * N + x];
                }
        }
        bsg_tile_group_shared_store(float, agg, __bsg_y * bsg_tiles_X + __bsg_x, partial_sum);
        bsg_tile_group_barrier(&r_barrier, &c_barrier);

        // Compute sum of the columns of the sum matrix
        if(__bsg_y == 0)
        {
                for(int y = 1; y < bsg_tiles_Y; y++)
                {
                        float other;
                        bsg_tile_group_shared_load(float, agg, y * bsg_tiles_X + __bsg_x, other);
                        partial_sum += other;
                }
                bsg_tile_group_shared_store(float, agg, __bsg_x, partial_sum);
        }
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        // Compute sum of row 0 of the row matrix
        if(__bsg_y == 0 && __bsg_x == 0)
        {
                for(int x = 1; x < bsg_tiles_X; x++)
                {
                        float other;
                        bsg_tile_group_shared_load(float, agg, x, other);
                        partial_sum += other;
                }
                bsg_tile_group_shared_store(float, agg, 0, partial_sum);
        }
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        float sum;
        bsg_tile_group_shared_load(float, agg, 0, sum);
        for(int y = start_y + __bsg_y; y < end_y; y += bsg_tiles_Y)
        {
                for(int x = start_x + __bsg_x; x < end_x; x += bsg_tiles_X)
                {
                        B[y * N + x] /= sum;
                }
        }
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
        return 0;
}
