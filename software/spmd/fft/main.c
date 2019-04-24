#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y
#include "bsg_tile_group_barrier.h"

#ifdef __clang__
#include "bsg_tilegroup.h"
#endif
#include <math.h>
#include <complex.h>

#define N 16

int fft_arr[N] = {1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
#ifdef __clang__
float complex STRIPE fft_work_arr[N];
/* #else */
/* float complex fft_work_arr[N/bsg_group_size]; */
/* typedef volatile float complex *bsg_remote_complex_ptr; */
/* #define bsg_remote_complex(x, y, local, addr) ((bsg_remote_complex_ptr)\ */
/*         (( REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS)\ */
/*             | ((y) << Y_CORD_SHIFTS) \ */
/*             | ((x) << X_CORD_SHIFTS) \ */
/*             | ((int) (local_addr))   \ */
/*                 )\ */
/*         ) */

/* #define bsg_complex_store(x,y,local_addr,val) do { *(bsg_remote_complex((x),(y),(local_addr))) = (float complex) (val); } while (0) */
/* #define bsg_complex_load(x,y,local_addr,val)  do { val = *(bsg_remote_complex((x),(y),(local_addr))) ; } while (0) */


/* float complex complex_remote_load(float complex *A, unsigned i) { */
/*     float complex val; */
/*     int tile_id = i % bsg_group_size; */
/*     int tile_x = tile_id / bsg_tiles_X; */
/*     int tile_y = tile_id % bsg_tiles_X; */
/*     int index = i / bsg_group_size; */
/*     bsg_remote_load(tile_x, tile_y, &A[index], val); */
/*     return val; */
/* } */

/* void complex_remote_store(float complex *A, unsigned i, float complex val) { */
/*     int tile_id = i % bsg_group_size; */
/*     int tile_x = tile_id / bsg_tiles_X; */
/*     int tile_y = tile_id % bsg_tiles_X; */
/*     int index = i / bsg_group_size; */
/*     bsg_remote_store(tile_x, tile_y, &A[index], val); */
/* } */

#endif

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1)

void clear_barriers(bsg_row_barrier *row, bsg_col_barrier *col) {
    row->_done_list[0] = 0;
    row->_done_list[1] = 0;
    row->_local_alert = 0;
    col->_done_list[0] = 0;
    col->_done_list[1] = 0;
    col->_local_alert = 0;
}

int work_arr_idx = 0;
/** @brief Swizzle the input data from DRAM into the order that FFT
 *         naturally processes
 */
void fft_swizzle(int start, int stride) {
    int val;
    if (N > stride) {
        fft_swizzle(start, stride * 2);
        fft_swizzle(start + stride, stride * 2);
    } else {
        val = fft_arr[start];
#ifdef __clang__
        fft_work_arr[work_arr_idx] = val;
/* #else */
/*         complex_remote_store(fft_work_arr, work_arr_idx, (float complex) val); */
#endif
        work_arr_idx += 1;
    }
}

/** @brief Perform an in-place fft recursively
 * */
#ifdef __clang__
void fft(float complex STRIPE *X, unsigned id) {
#else
void fft(float complex *X, unsigned id) {
#endif
    int even_idx, odd_idx, work_id, n = 2;
    float k_div_n, exp_val;
    float complex t_val, even_val, odd_val;
    while (n <= N) {
        work_id = 0;
        for (int i = 0; i < N; i += n) {
            for (int k = 0; k < n / 2; k++) {
                if (work_id != id) {
                    work_id = (work_id + 1) % bsg_group_size;
                    continue;
                }

                even_idx = i + k;
                odd_idx = even_idx + n / 2;

                k_div_n = (float) k / (float) n;
                exp_val = -2 * I * M_PI * k_div_n;
#ifdef __clang__
                odd_val = X[odd_idx];
                even_val = X[even_idx];
/* #else */
                /* odd_val = complex_remote_load(X, odd_idx); */
                /* even_val = complex_remote_load(X, even_idx); */
#endif

                // TODO Problem lines -- one works, one doesn't
                t_val = cexp(exp_val) * X[odd_idx];
                /* t_val = cexp(exp_val) * odd_val; */

#ifdef __clang__
                X[odd_idx] =  even_val - t_val;
                X[even_idx] = even_val + t_val;
/* #else */
                /* complex_remote_store(X, odd_idx, even_val - t_val); */
                /* complex_remote_store(X, even_idx, even_val + t_val); */
#endif
                work_id = (work_id + 1) % bsg_group_size;
            }
        }
        n = n * 2;
        bsg_tile_group_barrier(&r_barrier, &c_barrier);
    }
}

float magnitude(float complex x) {
    float mag_val = crealf(x) * crealf(x) + cimagf(x) * cimagf(x);
    return sqrt(mag_val);
}

int main()
{
    bsg_set_tile_x_y();
    if (bsg_id == 0) {
        fft_swizzle(0, 1);
    }
    bsg_tile_group_barrier(&r_barrier, &c_barrier);

    fft(fft_work_arr, bsg_id);

#ifdef __clang__
    if (bsg_id == 0) {
        for (unsigned i = 0; i < N; i++) {
            bsg_printf("a[%d] = {%d + %dj}\n", i, (int)crealf(fft_work_arr[i]),
                    (int) cimagf(fft_arr[i]));
        }
        bsg_finish();
    }
/* #else */
/*     for (unsigned i = 0; i < N/bsg_group_size; i++) { */
/*         bsg_printf("a[%d] = {%d + %dj}\n", i + bsg_id * (N/bsg_group_size), */
/*                 (int)crealf(fft_work_arr[i]), */
/*                 (int) cimagf(fft_arr[i])); */
/*     } */
/*     if (bsg_id == 0) { bsg_finish();} */
#endif
    bsg_wait_while(1);
}

