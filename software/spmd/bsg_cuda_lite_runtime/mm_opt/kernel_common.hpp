#ifndef _KERNEL_COMMON_H
#define _KERNEL_COMMON_H

#include <cstring>
#include <cstdint>
#include <math.h>

// BSG_TILE_GROUP_X_DIM and BSG_TILE_GROUP_Y_DIM must be defined
// before bsg_manycore.h and bsg_tile_group_barrier.h are
// included.
#define BSG_TILE_GROUP_X_DIM bsg_global_X
#define BSG_TILE_GROUP_Y_DIM (bsg_global_Y - 1)
// imaginary __bsg_pod_id and BSG_POD_DIM
#define __bsg_pod_id 0
#define BSG_POD_DIM 1
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_tile_group_barrier.hpp"
#include "hb_tensor.hpp"
#include <hb_assert.hpp>
#include <hb_tiled_for.hpp>
#include <hb_blocked_for.hpp>
#include <hb_spatial_for.hpp>
#include <hb_common.hpp>

bsg_attr_remote void* hb_memcpy(bsg_attr_remote void* bsg_attr_noalias dest,
                         const bsg_attr_remote void* bsg_attr_noalias src,
                         size_t n);

extern bsg_barrier<bsg_tiles_X, bsg_tiles_Y> g_barrier;

#endif // _KERNEL_COMMON_H
