#include <stdlib.h>
#include <machine/dramfs_fs.h>

#ifdef __spike__

  #include "spike.h"

#else // ifndef __spike__

  #include "bsg_manycore.h"
  #include "bsg_set_tile_x_y.h"

#endif // __spike__

void dramfs_init(void) {
  bsg_set_tile_x_y();

  // Init file system
  if(dramfs_fs_init() < 0) {
    exit(EXIT_FAILURE);
  }
}

void dramfs_exit(int exit_status) {
  if(exit_status == EXIT_SUCCESS) {
    bsg_finish();
  } else {
    bsg_fail();
  }
}

void dramfs_sendchar(char ch) {
  bsg_putchar(ch);
}
