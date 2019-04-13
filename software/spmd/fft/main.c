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
#else
float complex fft_work_arr[N];
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
        fft_work_arr[work_arr_idx] = val;
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
    float complex t_val;
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
                t_val = cexp(exp_val) * X[odd_idx];
                X[odd_idx] = X[even_idx] - t_val;
                X[even_idx] = X[even_idx] + t_val;
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

// 2993430
//  786850
int main()
{
    bsg_set_tile_x_y();
    if (bsg_id == 0) {
        fft_swizzle(0, 1);
    }
    bsg_tile_group_barrier(&r_barrier, &c_barrier);

    fft(fft_work_arr, bsg_id);

    if (bsg_id == 0) {
        for (unsigned i = 0; i < N; i++) {
            bsg_printf("a[%d] = {%d + %dj}\n", i, (int)crealf(fft_work_arr[i]),
                    (int) cimagf(fft_arr[i]));
        }
        bsg_finish();
    }

    bsg_wait_while(1);
}

