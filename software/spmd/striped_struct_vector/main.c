#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tilegroup.h"

#define N 32

typedef struct s {
    int i;
    char c;
    int j;
} struct_s;

struct_s STRIPE A[bsg_group_size][N] = {{{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},
                                         {1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},
                                         {1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},
                                         {1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1},{1,1,1}},
                                        {{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},
                                         {2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},
                                         {2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},
                                         {2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2},{2,2,2}},
                                        {{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},
                                         {3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},
                                         {3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},
                                         {3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3},{3,3,3}},
                                        {{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},
                                         {4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},
                                         {4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},
                                         {4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4},{4,4,4}}};

/* struct_s STRIPE A[bsg_group_size][N]; */

int STRIPE B[bsg_group_size];

__attribute__((noinline))
void vector_sum(int bsg_id) {
    int accum = 0;
    for (int i = 0; i < N; i++) {
#ifndef __clang__
        int i_val, j_val;
        char c_val;
        bsg_remote_load(bsg_x, bsg_y, &A[bsg_id][i].i, i_val);
        bsg_remote_load(bsg_x, bsg_y, &A[bsg_id][i].j, j_val);
        bsg_remote_load(bsg_x, bsg_y, &A[bsg_id][i].c, c_val);
        accum += i_val + j_val + c_val;
#else
        struct_s val = A[bsg_id][i];
        accum += val.i + val.j + val.c;
#endif
    }
#ifndef __clang__
    bsg_remote_store(bsg_x, bsg_y, &B[bsg_id], accum);
#else
    B[bsg_id] = accum;
#endif
    bsg_printf("B[%d] = %d\n", bsg_id, accum);
}

int main()
{
    bsg_set_tile_x_y();

    int bsg_id = bsg_x * bsg_tiles_X + bsg_y;
    vector_sum(bsg_id);

    if ((bsg_x == bsg_tiles_X-1) && (bsg_y == 0)) {
        bsg_finish();
    }
    bsg_wait_while(1);
}
