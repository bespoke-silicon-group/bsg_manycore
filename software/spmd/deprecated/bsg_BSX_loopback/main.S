#include "bsg_manycore_arch.h"

#define bsg_asm_remote_ptr(x,y,local_addr)  (   (REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS) \
                                               | ((y) << Y_CORD_SHIFTS )                     \
                                               | ((x) << X_CORD_SHIFTS )                     \
                                               | ( (local_addr)   )                          \
                                             )                                               \

#define FINISH_ADDR    bsg_asm_remote_ptr( FSB_X_CORD, bsg_tiles_Y, 0xEAD0)
#define DM_START       0x1000

.text 
li          a0,  FINISH_ADDR   ;
sw          zero,0x0( a0 )     ;

li          a1,  DM_START      ;
lr.w        t0,  0x0(a1)       ;
lr.w.aq     t0,  0x0(a1)       ;
