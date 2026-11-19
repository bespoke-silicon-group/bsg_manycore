#include <assert.h>
#include "bsg_hw_barrier_config_init.h"

static void check_mesh(int tx, int ty, const int *expected)
{
  int config[4];
  bsg_hw_barrier_config_init(config, tx, ty);
  for (int i = 0; i < tx*ty; i++) {
    assert(config[i] == expected[i]);
  }
}

int main(void)
{
  const int single[] = {0x50001};
  const int square[] = {0x20001, 0x40003, 0x20001, 0x5000b};
  const int row[] = {0x20001, 0x50007, 0x10001};
  const int column[] = {0x40001, 0x50019, 0x30001};

  check_mesh(1, 1, single);
  check_mesh(2, 2, square);
  check_mesh(3, 1, row);
  check_mesh(1, 3, column);
  return 0;
}
