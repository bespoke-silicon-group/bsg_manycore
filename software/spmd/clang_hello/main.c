#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tilegroup.h"

#define N 8

int STRIPE A[N][N] = {0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1};

int load_store_test(int j) {
    int y;
    int STRIPE *a_ptr = &A[1][1];
    bsg_printf("A starts at %x, starting ptr at %x\n",
            &A, &A[1][1]);
    for (int i = 0; i < N; i++) {
        *a_ptr = j;
        a_ptr++;
        A[i][i] = j;
    }
    for (int i = 0; i < N; i++) {
        y += A[i][i];
    }
    for (int i = 0; i < N; i++) {
        A[0][i] = y + j;
    }
    y++;
    A[2][2] = y;
    A[j][j] = 4;
    return A[j][j-1];
}

int main()
{
    bsg_set_tile_x_y();

    bsg_remote_ptr_io_store(IO_X_INDEX,0x1260,bsg_x);
    bsg_remote_ptr_io_store(IO_X_INDEX,0x1264,bsg_y);
    bsg_remote_ptr_io_store(IO_X_INDEX,0x1234,0x13);

    if ((bsg_x == bsg_tiles_X-1) && (bsg_y == bsg_tiles_Y-1)) {
        bsg_remote_ptr_io_store(IO_X_INDEX, 0x1300, load_store_test(bsg_x + 1));
        bsg_finish();
    }
    bsg_wait_while(1);
}
