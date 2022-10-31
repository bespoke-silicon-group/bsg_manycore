#include "bsg_cuda_lite_barrier.h"
#if defined(BSG_BARRIER_HW_TILE_GROUP_USE_BSG_TILE_GROUP_BARRIER)
#include "bsg_tile_group_barrier.hpp"
#endif

int *__cuda_barrier_cfg;


#if defined(BSG_BARRIER_HW_TILE_GROUP_USE_BSG_TILE_GROUP_BARRIER)
bsg_barrier<bsg_tiles_X, bsg_tiles_Y> __cuda_tg_barrier;

/**
 * Initialize the tile-group barrier.
 * This function should only be called once for the lifetime of the tile-group.
 */
void bsg_barrier_hw_tile_group_init()
{
    int sense = 1;
    __cuda_tg_barrier.reset();        
    bsg_barrier_amoadd(&__cuda_barrier_cfg[0], &sense);
}

/**
 * Invoke the tile-group barrier.
 */
void bsg_barrier_hw_tile_group_sync()
{
    __cuda_tg_barrier.sync();
}
#endif
