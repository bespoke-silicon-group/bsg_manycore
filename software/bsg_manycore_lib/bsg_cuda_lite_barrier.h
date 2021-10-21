#ifndef BSG_CUDA_LITE_BARRIER_H
#define BSG_CUDA_LITE_BARRIER_H
#include "bsg_barrier_amoadd.h"
#include "bsg_hw_barrier.h"
#include "bsg_tile_config_vars.h"
#ifdef __cplusplus
extern "C" {
#endif
extern int *__cuda_barrier_cfg;

static inline void bsg_barrier_hw_tile_group_init()
{
    int sense = 1;
    // initalize csr
    int cfg = __cuda_barrier_cfg[1+__bsg_id];
    asm volatile ("csrrw x0, 0xfc1, %0" : : "r" (cfg));
    // sync with amoadd barrier
    bsg_barrier_amoadd(&__cuda_barrier_cfg[0], &sense);
}

static inline void bsg_barrier_hw_tile_group_sync()
{
    bsg_barsend();
    bsg_barrecv();
}
#ifdef __cplusplus
}
#endif
#endif
