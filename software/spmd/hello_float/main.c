#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

float data[2] __attribute__ ((section (".dram"))) = {3.141592, 2.7182818};

#define flt(X) (*(float*)&X)
#define hex(X) (*(int*)&X)

int main()
{
  bsg_set_tile_x_y();

  if ((__bsg_x == 0) && (__bsg_y == 0))
  {
    float sum = 0;
    float prod = 1;
    float diff = data[0] - data[1];

    for (int i = 0; i < 2; i++)
      sum += data[i]; 
      
    for (int i = 0; i < 2; i++)
      prod *= data[i]; 
   
    if (hex(sum) == 0x40bb8416)
      bsg_printf("sum: %x\n", hex(sum));
    else
      bsg_fail_x(0);

    if (hex(prod) == 0x4108a2be)
      bsg_printf("prod: %x\n", hex(prod));
    else 
      bsg_fail_x(0);

    if (hex(diff) == 0x3ed8bc20)
      bsg_printf("diff: %x\n", hex(diff));
    else
      bsg_fail_x(0);


    bsg_finish();
  }

  bsg_wait_while(1);
}
