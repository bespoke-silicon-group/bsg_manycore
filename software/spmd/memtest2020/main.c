// This test the memory system by accessling a wide range of addresses using varying strides.
// The strides are 2^n-1 with n > 0. This exercises vcache replacement.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int data __attribute__ ((section (".dram"))) = {0};
#define N 256


int get_stride(int n)
{
  int stride = 1;
  for (int i = 0; i < n; i++)
  {
    stride = stride * 2;
  }
  return stride-1;
}

int main()
{
  bsg_set_tile_x_y();

  int idx;
  int* dram_ptr = &data;

  for (int k = 0; k < 2; k++)
  {
    for (int n = 1; n < 21; n++)
    {
      int stride = get_stride(n);
  
      // store
      idx = 0;
      for (int i = 0; i < N; i++)
      {
        dram_ptr[idx] = i;
        idx += stride;
      }

      // load
      int load_val[N];
      idx = 0;
      for (int i = 0; i < N; i++)
      {
        load_val[i] = dram_ptr[idx];
        idx += stride;
      }

      // validate
      for (int i = 0; i < N; i++)
      {
        if (load_val[i] != i) bsg_fail();
      }
    }
  }

  bsg_finish();
  bsg_wait_while(1);
}

