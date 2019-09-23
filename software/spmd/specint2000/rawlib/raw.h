#ifndef _RAW_H
#define _RAW_H

#ifdef __host__

#elif __spike__

#include "spike.h"

#else // ifndef __spike__

#include "bsg_manycore.h"
#include "bsg_manycore_arch.h"
#include "bsg_set_tile_x_y.h"

#endif // __spike__

void timebegin();
void timeend();

#define raw_get_tile_num() \
  __bsg_id

#define raw_test_pass_reg(val) \
  bsg_remote_ptr_io_store(IO_X_INDEX, 0, val)

#define __MINNESTART__ ({ \
  printf("STRAT: "); \
  bsg_print_time(); \
  printf("\n");})

#define __MINNEEND__ ({ \
  printf("END: "); \
  bsg_print_time(); \
  printf("\n");})

#endif // _RAW_H
