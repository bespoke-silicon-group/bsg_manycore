#include <stdlib.h>
#include <unistd.h>
#include <machine/bsg_newlib_fs.h>
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

void bsg_newlib_init(void) {
  bsg_set_tile_x_y();

  // Only bottom left tile handles the filesystem
  if((__bsg_x == 0) && (__bsg_y == bsg_tiles_Y-1)) {
    // Init file system
    if(bsg_newlib_fs_init() < 0) {
      exit(EXIT_FAILURE);
    }
  } else {
    // As of now, newlib only runs on a single core!
    bsg_wait_while(1);
  }
}

void bsg_newlib_exit(int exit_status) {
  // close stdio
  close(0);
  close(1);
  close(2);

  if(exit_status == EXIT_SUCCESS) {
    bsg_finish();
  } else {
    bsg_fail();
  }

  bsg_wait_while(1);
}

void bsg_newlib_sendchar(char ch) {
  bsg_putchar(ch);
}
