#ifndef BSG_CUDA_LITE_BARRIER_H
#define BSG_CUDA_LITE_BARRIER_H
#include "bsg_barrier_amoadd.h"
#ifdef BSG_ARCH_HW_BARRIER
#include "bsg_hw_barrier.h"
#endif
#include "bsg_tile_config_vars.h"
#ifdef __cplusplus
extern "C" {
#endif
extern int *__cuda_barrier_cfg;
#ifndef BSG_ARCH_HW_BARRIER
extern int __cuda_barrier_sense;
#endif

/**
 * Initialize the tile-group barrier.
 * This function should only be called once for the lifetime of the tile-group.
 */
static inline void bsg_barrier_hw_tile_group_init()
{
#ifdef BSG_ARCH_HW_BARRIER
    int sense = 1;
    // initalize csr
    int cfg = __cuda_barrier_cfg[1+__bsg_id];
    asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (cfg));
    // reset Pi
    asm volatile ("csrrwi x0, 0xfc2, 0");
    // sync with amoadd barrier
    bsg_barrier_amoadd(&__cuda_barrier_cfg[0], &sense);
#endif
}

/**
 * Invoke the tile-group barrier.
 */
static inline void bsg_barrier_hw_tile_group_sync()
{
#ifdef BSG_ARCH_HW_BARRIER
    bsg_barsend();
    bsg_barrecv();
#else
    bsg_barrier_amoadd(&__cuda_barrier_cfg[0], &__cuda_barrier_sense);
#endif
}
#ifdef __cplusplus
}
#endif
#endif
