#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int main() {
  bsg_set_tile_x_y();

  int stream_len = 1000;

  bsg_putchar('\n');

  for(int i=0; i<stream_len; i++) {
    bsg_putchar('$');
  }

  bsg_putchar('\n');

  bsg_finish();
}
