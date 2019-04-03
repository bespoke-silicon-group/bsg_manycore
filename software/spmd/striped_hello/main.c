#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tilegroup.h"

#define N bsg_group_size

typedef struct test_s1 {
    int i;
    short s;
} test_s1;

typedef struct test_s {
    int i;
    char c;
    test_s1 s;
} test_t;

int STRIPE A[N][N];
char STRIPE B[N][N];
test_t STRIPE C[N][N];

void indexing_test() {
    int val;
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            val = (i * 17) + j * 3;
            A[i][j] = val;
        }
    }
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            val = (i * 17) + j * 3;
            if (A[i][j] != val) {
                bsg_fail();
            }
        }
    }
    bsg_printf("Passed indexing test\n");
}


void char_ptr_arith_test() {
    char STRIPE *arr = &B[0][0];
    char curr = 0;
    while (curr < N * N) {
        *arr = curr;
        arr++;
        curr++;
    }
    curr = 0;
    arr = &B[0][0];
    while (curr < N * N) {
        if (*arr != curr) {
            bsg_fail();
        }
        arr++;
        curr++;
    }
    bsg_printf("Passed char_ptr_arith_test\n");
}


void short_ptr_arith_test() {
    short STRIPE *arr = (short STRIPE *) &A[0][0];
    short curr = 0;
    while (curr < N * N) {
        *arr = curr * curr;
        curr++;
        arr++;
    }
    curr = 0;
    arr = (short STRIPE *) &A[0][0];
    while (curr < N * N) {
        if (*arr != curr * curr) { bsg_fail();}
        curr++;
        arr++;
    }
    bsg_printf("Passed short_ptr_arith_test\n");
}


void remote_load_store_test(int id) {
    int other_id = (id) ? 0 : 3;
    for (int i = 0; i < N; i++) {
        A[i][other_id] = (other_id * 2) + i * 5;
        while (A[i][id] != (id * 2) + i * 5);
    }
    bsg_printf("Passed remote_load_store_test; id = %d\n", id);
}

void struct_test() {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            test_t val = { .i = i * 5 + j, .c = i+j,
                .s = {.i = i & j, .s = i / j}};
            if (j & 1) {
                C[i][j] = val;
            } else {
                C[i][j].i = val.i;
                C[i][j].c = val.c;
                C[i][j].s.i = val.s.i;
                C[i][j].s.s = val.s.s;
            }
        }
    }
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            test_t val;
            if (j & 1) {
                val.i = C[i][j].i;
                val.c = C[i][j].c;
                val.s.i = C[i][j].s.i;
                val.s.s = C[i][j].s.s;
            } else {
                val = C[i][j];
            }
            if ((val.i != i * 5 + j) ||
                    (val.c != i+j) ||
                    (val.s.i != (i & j)) ||
                    (val.s.s != i / j)) {
                bsg_fail();
            }
        }
    }
    bsg_printf("Passed struct_test\n");
}

int main()
{
    bsg_set_tile_x_y();

    int bsg_id = bsg_x * bsg_tiles_X + bsg_y;

    if ((bsg_x == 0) && (bsg_y == 0)) {
        remote_load_store_test(bsg_id);
    }
    if ((bsg_x == bsg_tiles_X-1) && (bsg_y == bsg_tiles_Y-1)) {
        remote_load_store_test(bsg_id);

        indexing_test();
        char_ptr_arith_test();
        short_ptr_arith_test();
        struct_test();

        bsg_finish();
    }
    bsg_wait_while(1);
}
