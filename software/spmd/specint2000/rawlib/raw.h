#ifndef _RAW_H
#define _RAW_H

#include "bsg_manycore.h"
#include "bsg_manycore_arch.h"
#include "bsg_set_tile_x_y.h"

void timebegin();
void timeend();

#define raw_get_tile_num() __bsg_id
#define raw_test_pass_reg(val) bsg_remote_ptr_io_store(IO_X_INDEX, 0, val)

#endif // _RAW_H
