#include <stdlib.h>
#include <machine/bsg_newlib_fs.h>

#ifdef __spike__

#include "spike.h"

#else // ifndef __spike__

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#endif // __spike__

void bsg_newlib_init(void) {
  // Init file system
  if(bsg_newlib_fs_init() < 0) {
    exit(EXIT_FAILURE);
  }
}

void bsg_newlib_exit(int exit_status) {
  if(exit_status == EXIT_SUCCESS) {
    bsg_finish();
  } else {
    bsg_fail();
  }
}

void bsg_newlib_sendchar(char ch) {
  bsg_putchar(ch);
}
