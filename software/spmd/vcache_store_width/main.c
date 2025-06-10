#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

volatile unsigned var __attribute__ ((section (".dram"))) = 0;

void check(unsigned actual, unsigned expect, int id)
{
  if(actual != expect) {
    bsg_printf("MISMATCH: actual: %x expect: %x at %d\n", actual, expect, id);
    bsg_fail();
  }
}

int main()
{
  // Testing byte store
  var = 0xFFFFFFFFU;
  *((unsigned char *)&var + 0) = 0U;
  check(var, 0xFFFFFF00U, 0);

  var = 0xFFFFFFFFU;
  *((unsigned char *)&var + 1) = 0U;
  check(var, 0xFFFF00FFU, 1);

  var = 0xFFFFFFFFU;
  *((unsigned char *)&var + 2) = 0U;
  check(var, 0xFF00FFFFU, 2);

  var = 0xFFFFFFFFU;
  *((unsigned char *)&var + 3) = 0U;
  check(var, 0x00FFFFFFU, 3);

  // Testing half store
  var = 0xFFFFFFFFU;
  *((unsigned short *)&var + 0) = 0U;
  check(var, 0xFFFF0000U, 4);

  var = 0xFFFFFFFFU;
  // the '+1' here adds 2 to the address due to the type cast
  *((unsigned short *)&var + 1) = 0U;
  check(var, 0x0000FFFFU, 5);

  // Testing word store
  var = 0xFFFFFFFFU;
  *((unsigned *)&var + 0) = 0U;
  check(var, 0U, 6);

  bsg_finish();
}

