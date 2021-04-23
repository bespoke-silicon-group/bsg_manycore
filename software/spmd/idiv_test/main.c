
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 6
int a[N] __attribute__ ((section (".dram"))) = {
  110
  ,10001
  ,100001
  ,1000000000
  ,1010010010
  ,-10000
};
int b[N] __attribute__ ((section (".dram"))) = {
  10
  ,7
  ,37
  ,77777
  ,77
  ,13
};
int expected[N] __attribute__ ((section (".dram"))) = {
  11
  ,1428
  ,2702
  ,12857
  ,13117013
  ,-769
};

void test_div(int a, int b, int expected)
{
  volatile int result = a / b;
  if (result != expected)
  {
    bsg_fail();
    bsg_wait_while(1);
  }
}


void main()
{
  //int i;
  bsg_set_tile_x_y();

  for (int i = 0; i < N; i++) 
  {
    test_div(a[i], b[i], expected[i]);
  }



  bsg_finish();
  bsg_wait_while(1);
}

