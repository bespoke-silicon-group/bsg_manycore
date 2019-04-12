#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#ifdef __clang__
#include "bsg_tilegroup.h"
#endif

#define N 128

#ifdef __clang__
int STRIPE A[bsg_group_size][N] = {{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
                                    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
                                    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
                                    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1},
                                   {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
                                    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
                                    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
                                    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2},
                                   {3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
                                    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
                                    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
                                    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3},
                                   {4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
                                    4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
                                    4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
                                    4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4}};
/* int STRIPE A[bsg_group_size][N]; */
int STRIPE B[bsg_group_size];
#else
int A[N] = {2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
            2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
            2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
            2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2};
int B[1];
#endif


void vector_sum(int bsg_id) {
    int accum = 0, val;
#ifdef __clang__
    for (int i = 0; i < N; i++) {
        val = A[bsg_id][i];
#else
    int tile_x, tile_y, index;
    for (int i = bsg_id; i < N * bsg_group_size; i += bsg_group_size) {
        int tile_id = i % bsg_group_size;
        tile_x = tile_id / bsg_tiles_X;
        tile_y = tile_id % bsg_tiles_X;
        index = i / bsg_group_size;
        bsg_remote_load(tile_x, tile_y, &A[index], val);
        /* bsg_printf("{%d, %d, %x} = %d", tile_x, tile_y, &A[index], val); */
#endif
        accum += val;
    }
#ifdef __clang__
    B[bsg_id] = accum;
#else
    tile_x = bsg_id % bsg_tiles_X;
    tile_y = bsg_id / bsg_tiles_Y;
    bsg_remote_store(tile_x, tile_y, &B[0], accum);
#endif
    bsg_printf("B[%d] = %d\n", bsg_id, accum);
}

int main()
{
    bsg_set_tile_x_y();

    int bsg_id = bsg_x * bsg_tiles_X + bsg_y;
    vector_sum(bsg_id);

    if ((bsg_x == 0) && (bsg_y == 0)) {
        bsg_finish();
    }
    bsg_wait_while(1);
}
