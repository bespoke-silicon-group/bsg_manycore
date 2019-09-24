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

#define N 8

int fft_arr[N] = {
                  1,0,1,0,1,0,1,0,
                  };

float complex fft_dram_arr[N];
#ifdef __clang__
float complex STRIPE fft_work_arr[N];
#else
float complex fft_work_arr[N/bsg_group_size];
typedef volatile float complex *bsg_remote_complex_ptr;
#define bsg_remote_complex(x, y, local_addr) ((bsg_remote_complex_ptr)\
        (( REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS)\
            | ((y) << Y_CORD_SHIFTS) \
            | ((x) << X_CORD_SHIFTS) \
            | ((int) (local_addr))   \
                )\
        )

#define bsg_complex_store(x,y,local_addr,val) do { *(bsg_remote_complex((x),(y),(local_addr))) = (float complex) (val); } while (0)
#define bsg_complex_load(x,y,local_addr,val)  do { val = *(bsg_remote_complex((x),(y),(local_addr))) ; } while (0)


float complex complex_remote_load(float complex *A, unsigned i) {
    float complex val;
    int tile_id = i % bsg_group_size;
    int tile_x = tile_id / bsg_tiles_X;
    int tile_y = tile_id % bsg_tiles_X;
    int index = i / bsg_group_size;
    bsg_complex_load(tile_x, tile_y, &A[index], val);
    return val;
}

void complex_remote_store(float complex *A, unsigned i, float complex val) {
    int tile_id = i % bsg_group_size;
    int tile_x = tile_id / bsg_tiles_X;
    int tile_y = tile_id % bsg_tiles_X;
    int index = i / bsg_group_size;
    bsg_complex_store(tile_x, tile_y, &A[index], val);
}

#endif

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

int work_arr_idx = 0;
/** @brief Swizzle the input data from DRAM into the order that FFT
 *         naturally processes
 */
#ifdef __clang__
void fft_swizzle(int start, int stride, int *input, float complex STRIPE *output) {
#else
void fft_swizzle(int start, int stride, int *input, float complex *output) {
#endif
    int val;
    if (N > stride) {
        fft_swizzle(start, stride * 2, input, output);
        fft_swizzle(start + stride, stride * 2, input, output);
    } else {
        val = input[start];
#ifdef __clang__
        output[work_arr_idx] = val;
#else
        complex_remote_store(output, work_arr_idx, (float complex) val);
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
    float k_div_n;
    float complex exp_val, t_val, even_val, odd_val;
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
#else
                odd_val = complex_remote_load(X, odd_idx);
                even_val = complex_remote_load(X, even_idx);
#endif

                t_val = cexp(exp_val) * odd_val;

#ifdef __clang__
                X[odd_idx] =  even_val - t_val;
                X[even_idx] = even_val + t_val;
#else
                complex_remote_store(X, odd_idx, even_val - t_val);
                complex_remote_store(X, even_idx, even_val + t_val);
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


void fft_kernel(int *input, float complex *output) {
    bsg_set_tile_x_y();
    if (bsg_id == 0) bsg_print_stat(0);
    if (bsg_id == 0) { fft_swizzle(0, 1, input, fft_work_arr);}
    bsg_tile_group_barrier(&r_barrier, &c_barrier);
    fft(fft_work_arr, bsg_id);

    if (bsg_id == 0) {
        for (int i = 0; i < N; i++) {
#ifdef __clang__
            output[i] = fft_work_arr[i];
#else
            output[i] = complex_remote_load(fft_work_arr, i);
#endif
        }
    }
    if (bsg_id == 0) bsg_print_stat(0xdead);
}


int main()
{

    fft_kernel(fft_arr, fft_dram_arr);


    float complex val;
    int real_val, imag_val;
    if (bsg_id == 0) {
        for (unsigned i = 0; i < N; i++) {
            val = fft_dram_arr[i];
            real_val = (int) crealf(val);
            imag_val = (int) cimagf(val);
            if ((i % 4 == 0) && (real_val != 4)) {
                bsg_printf("fail1\n");
                bsg_fail();
            } else if ((i % 4 != 0) && (real_val != 0)) {
                bsg_printf("fail2\n");
                bsg_fail();
            }
            if (imag_val != 0) {
                bsg_printf("fail3\n");
                bsg_fail();
            }
        }
        bsg_finish();
    }
    bsg_wait_while(1);
}


