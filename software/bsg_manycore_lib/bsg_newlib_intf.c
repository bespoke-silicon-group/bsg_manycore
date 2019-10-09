#include <stdlib.h>
#include <machine/dramfs_fs.h>

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#ifdef __spike__
#include "spike.h"
#endif

void dramfs_init(void) {
  #ifdef __spike__
    replace_spike_call(set_tile_x_y);
  #else
    bsg_set_tile_x_y();
  #endif

  // Init file system
  if(dramfs_fs_init() < 0) {
    exit(EXIT_FAILURE);
  }
}

void dramfs_exit(int exit_status) {
  if(exit_status == EXIT_SUCCESS) {
    #ifdef __spike__
      replace_spike_call(finish);
    #else
      bsg_finish();
    #endif
  } else {
    #ifdef __spike__
      replace_spike_call(fail);
    #else
      bsg_fail();
    #endif
  }
}

void dramfs_sendchar(char ch) {
  #ifdef __spike__
    replace_spike_call(putchar, ch);
  #else
    bsg_putchar(ch);
  #endif
}
