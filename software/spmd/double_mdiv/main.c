#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

typedef union {
  struct ints {
    // Little-endian
    int lo;
    int hi;
  } i;

  double d;
} double_ints_t;

int main()
{
  bsg_set_tile_x_y();

  if (bsg_x == 0 && bsg_y == 0) {
    double_ints_t a = {.i.hi=0xbfa1cb88, .i.lo=0x587665f6};
    double_ints_t b = {.i.hi=0x3f60a8f3, .i.lo=0x531799ac};
    double_ints_t c = {.i.hi=0x4043bd3c, .i.lo=0xc9be45de};
    double_ints_t expected = {.i.hi=0xbebe09c5, .i.lo=0x88e07a4d};

    double_ints_t observed;
    observed.d = a.d * b.d / c.d;

    bsg_printf("observed=%08x%08x expected=%08x%08x\n"
        , observed.i.hi, observed.i.lo, expected.i.hi, expected.i.lo);

    if (observed.d != expected.d) bsg_fail();
  }

  bsg_finish();
}

