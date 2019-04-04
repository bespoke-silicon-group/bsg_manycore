#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tilegroup.h"

#define N bsg_group_size

int STRIPE A[N][N] = {{1, 2, 3, 4},
                      {6, 4, 2, 1},
                      {5, 4, 3, 2},
                      {7, 5, 8, 2}};

int STRIPE B[N];

void vector_sum(int bsg_id) {
    int accum = 0;
    for (int i = 0; i < N; i++) {
        accum += A[bsg_id][i];
    }
    B[bsg_id] = accum;
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
