#include <bsg_cuda_lite_runtime.h>
#include <string.h>

int main()
{
    __wait_until_valid_func();
    return 0;
}

//int gups(bsg_attr_remote int *__restrict G, int *__restrict A, int n);
int gups(int *__restrict G, int *__restrict A, int n);
    
#define BLOCK_SIZE 32
__attribute__((noinline))
//int cuda_gups(bsg_attr_remote int *__restrict G, bsg_attr_remote int *__restrict A, int n_per_core)
int cuda_gups(int *__restrict G, int *__restrict A, int n_per_core)
{
    int A_local[BLOCK_SIZE];

    for (int i = 0; i < n_per_core; i += BLOCK_SIZE) {

        /* bsg_unroll(32) */
        /* for (int j = 0; j < BLOCK_SIZE; j++) { */
        /*     A_local[j] = A[bsg_id * n_per_core + i + j]; */
        /* } */
        memcpy(A_local, &A[bsg_id * n_per_core + i], sizeof(A_local));

        gups(G, A_local, BLOCK_SIZE);
    }

    return 0;
}

