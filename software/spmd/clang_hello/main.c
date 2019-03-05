#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

//---------------------------------------------------------------
#define STRIDE __attribute__((address_space(1)))
#define DRAM __attribute((section(".dram.data")))

// Remote EPA: 01YY_YYYY_XXXX_XXPP_PPPP_PPPP_PPPP_PPPP

// Passed from linker -- indicates start of striped arrays in DMEM
extern unsigned _striped_data_start;

volatile int *get_ptr_val(int STRIDE *arr_ptr, unsigned elem_size) {
    unsigned start_ptr = (unsigned) &_striped_data_start;
    unsigned ptr = (unsigned) arr_ptr;
    unsigned index = ((ptr) - start_ptr) / elem_size;
    unsigned core_id = index % (group_size);
    unsigned local_addr = start_ptr + (index / group_size) * elem_size;
    unsigned tile_x = core_id / bsg_tiles_X;
    unsigned tile_y = core_id - (tile_x * bsg_tiles_X);
    unsigned remote_ptr_val = REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS |
                              tile_x << X_CORD_SHIFTS |
                              tile_y << Y_CORD_SHIFTS |
                              local_addr;
    unsigned ptr_val = (tile_x == bsg_x && tile_y == bsg_y) ?
        local_addr : remote_ptr_val;
    bsg_printf("ID = %u, index = %u; striped_data_start = 0x%x\n",
            core_id, index, &_striped_data_start);
    bsg_printf("Pointer is (%u, %u, 0x%x)\n", tile_x, tile_y, local_addr);
    bsg_printf("Final Pointer is 0x%x\n", ptr_val);
    return (volatile int *) ptr_val;
}

void extern_store(int STRIDE *arr_ptr, unsigned elem_size, unsigned val) {
    bsg_printf("\nCalling extern_store(0x%x, %d, %d)\n",
            (unsigned) arr_ptr,
            elem_size, val);
    volatile int *ptr = get_ptr_val(arr_ptr, elem_size);
    bsg_printf("Performing store\n");
    *ptr = val;
}

int extern_load(int STRIDE *arr_ptr, unsigned elem_size) {
    bsg_printf("\nCalling extern_load(0x%x, %d)\n",
            (unsigned) arr_ptr,
            elem_size);
    volatile int *ptr = get_ptr_val(arr_ptr, elem_size);
    return *ptr;
}

//---------------------------------------------------------------

#define N 8
int STRIDE A[N][N] = {0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1,
                      0x5, 0x1, 0x10, 0x6, 0x4, 0x13, 0x10, 0x1};

int __attribute((section(".striped.data"))) B[5];

int load_store_test(int j) {
    int y;
    for (int i = 0; i < N; i++) {
        A[i][i] = j;
    }
    for (int i = 0; i < N; i++) {
        y += A[i][i];
    }
    for (int i = 0; i < N; i++) {
        A[0][i] = y + j;
    }
    /* bsg_remote_ptr_io_store(IO_X_INDEX,0x1200,y); */
    /* y++; */
    /* bsg_remote_ptr_io_store(IO_X_INDEX,0x1200,y); */
    /* A[2][2] = y; */
    /* A[j][j] = 4; */
    return A[j][j-1];
}

int main()
{
    bsg_set_tile_x_y();

    /* bsg_remote_ptr_io_store(IO_X_INDEX,0x1260,bsg_x); */
    /* bsg_remote_ptr_io_store(IO_X_INDEX,0x1264,bsg_y); */
    /* bsg_remote_ptr_io_store(IO_X_INDEX,0x1234,0x13); */

    if ((bsg_x == bsg_tiles_X-1) && (bsg_y == bsg_tiles_Y-1)) {
        bsg_remote_ptr_io_store(IO_X_INDEX, 0x1300, load_store_test(bsg_x + 1));
        bsg_finish();
    }
    bsg_wait_while(1);
}
