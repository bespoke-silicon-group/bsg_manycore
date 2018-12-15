#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <math.h>
#include <complex.h>

#define N 8
#define PI 3.1415826
#define DRAM __attribute__((section(".dram.data")))

int fft_dram_arr[N] DRAM = {0x1, 0x1, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0};
int work_arr_idx = 0;
float complex fft_arr[N];

/** @brief Swizzle the input data from DRAM into the order that FFT
 *         naturally processes
 *  @bug None!!! Output checked
 */
void fft_swizzle(int *src, float complex *dest, int start, int stride) {
    int val;
    if (N > stride) {
        fft_swizzle(src, dest, start, stride * 2);
        fft_swizzle(src, dest, start + stride, stride * 2);
        return;
    } else {
        bsg_dram_load(&fft_dram_arr[start], val);
        dest[work_arr_idx] = val;
        work_arr_idx += 1;
    }
}

/** @brief Perform an in-place fft recursively
 * */
void fft(float complex *X) {
    int even_idx, odd_idx, n = 2;
    float complex t_val, k_div_n;
    while (n <= N) {
        for (int i = 0; i < N; i += n) {
            for (int k = 0; k < n / 2; k++) {
                even_idx = i + k;
                odd_idx = even_idx + n / 2;
                k_div_n = (float) k / (float) n;
                // XXX TODO Switch back to cexp() -- not found by linker
                t_val = cexp(-2 * I * PI * k_div_n) * X[odd_idx];
                bsg_remote_ptr_io_store(IO_X_INDEX, 0x2000, i);
                bsg_remote_ptr_io_store(IO_X_INDEX, 0x2010, 0x20);
                // TODO Fails on below line!!
                float complex y = X[even_idx] - t_val;
                bsg_remote_ptr_io_store(IO_X_INDEX, 0x2020, k);
                X[odd_idx] = y;
                X[even_idx] = X[even_idx] + t_val;
            }
        }
        n = n * 2;
    }
}

float magnitude(float complex x) {
    //TODO XXX Switch back -- sqrt() not found by linker
    //return sqrt(creal(x) * creal(x) + cimag(x) * cimag(x));
    return creal(x) * creal(x) + cimag(x) * cimag(x);
}

// Load in memory that tiles in a group will share
void init(int core_id) {

}

int main()
{
  bsg_set_tile_x_y();
  int core_id = bsg_x * bsg_tiles_X + bsg_y;


  int val = 0xdeadbeef;
  bsg_dram_load(&fft_dram_arr[core_id], val);
  bsg_remote_ptr_io_store(IO_X_INDEX, 0x1000 + core_id * 4, val);

  if ((bsg_x == bsg_tiles_X-1) && (bsg_y == bsg_tiles_Y-1)) {
    bsg_remote_ptr_io_store(IO_X_INDEX, 0x2000, &fft_dram_arr[0]);
    fft_swizzle(fft_dram_arr, fft_arr, 0, 1);
    fft(fft_arr);
    for (unsigned i = 0; i < N; i++) {
        bsg_remote_ptr_io_store(IO_X_INDEX, 0x4000 + i, magnitude(fft_arr[i]));
    }
    bsg_finish();
  }

  bsg_wait_while(1);
}

