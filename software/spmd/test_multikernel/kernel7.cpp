
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"

#include "kernel.hpp"

#define KERNEL_NUM 7

#if TEST_VAR == KERNEL_NUM
KERNEL_DEF(KERNEL_NUM)
#else
#error TEST_VAR != KERNEL_NUM
#endif

