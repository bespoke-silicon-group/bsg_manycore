#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#ifdef __clang__
#include "bsg_tilegroup.h"
#endif
#include <math.h>
#include <complex.h>

#define N 4

/* int fft_arr[N] = {1, 1, 1, 1, 1, 1, 1, 1, */
/*                   0, 0, 0, 0, 0, 0, 0, 0}; */
int fft_arr[N] = {1,1,1,1};
#ifdef __clang__
float complex STRIPE fft_work_arr[N];
#else
float complex fft_work_arr[N];
#endif

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
void fft(float complex *X) {
    int even_idx, odd_idx, n = 2;
    float k_div_n, exp_val;
    float complex t_val;
    while (n <= N) {
        for (int i = 0; i < N; i += n) {
            for (int k = 0; k < n / 2; k++) {
                even_idx = i + k;
                odd_idx = even_idx + n / 2;
                k_div_n = (float) k / (float) n;

                exp_val = -2 * I * M_PI * k_div_n;
                t_val = cexp(exp_val) * X[odd_idx];
                X[odd_idx] = X[even_idx] - t_val;
                X[even_idx] = X[even_idx] + t_val;
            }
        }
        n = n * 2;
    }
}

float magnitude(float complex x) {
    float mag_val = crealf(x) * crealf(x) + cimagf(x) * cimagf(x);
    return sqrt(mag_val);
}

int main()
{
  bsg_set_tile_x_y();

  if ((bsg_x == bsg_tiles_X-1) && (bsg_y == bsg_tiles_Y-1)) {
    bsg_printf("Starting FFT\n");
    fft_swizzle(0, 1);
    for (unsigned i = 0; i < N; i++) {
        bsg_printf("A[%d] = {%d + %dj}\n", i, (int)crealf(fft_work_arr[i]),
                (int)cimagf(fft_arr[i]));
    }
    fft(fft_work_arr);
    for (unsigned i = 0; i < N; i++) {
        bsg_printf("A[%d] = {%d + %dj}\n", i, (int)crealf(fft_work_arr[i]),
                (int) cimagf(fft_arr[i]));
    }
    bsg_finish();
  }

  bsg_wait_while(1);
}

