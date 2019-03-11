#ifndef _BSG_MANYCORE_ARCH_H
#define _BSG_MANYCORE_ARCH_H

//------------------------------------------------------
// 0. basic SoC definitaion
//------------------------------------------------------
#define IO_X_INDEX     ((bsg_tiles_X)-1) 
//in words.
#define EPA_ADDR_BITS                   18
//------------------------------------------------------
// 1. X/Y dimention setting/Checking.
//------------------------------------------------------
#ifndef bsg_tiles_X
#error bsg_tiles_X must be defined
#endif

#ifndef bsg_tiles_Y
#error bsg_tiles_Y must be defined
#endif

#define bsg_routers_Y ( (bsg_tiles_Y) +1) 

#if bsg_tiles_X == 1
#define bsg_noc_xbits 1
#elif bsg_tiles_X == 2
#define bsg_noc_xbits 1
#elif bsg_tiles_X == 3
#define bsg_noc_xbits 2
#elif bsg_tiles_X == 4
#define bsg_noc_xbits 2
#elif bsg_tiles_X == 5
#define bsg_noc_xbits 3
#elif bsg_tiles_X == 6
#define bsg_noc_xbits 3
#elif bsg_tiles_X == 7
#define bsg_noc_xbits 3
#elif bsg_tiles_X == 8
#define bsg_noc_xbits 3
#elif bsg_tiles_X == 9
#define bsg_noc_xbits 4
#elif bsg_tiles_X == 16
#define bsg_noc_xbits 4
#else
#error Unsupported bsg_tiles_X
#endif

#if bsg_routers_Y == 1
#define bsg_noc_ybits 1
#elif bsg_routers_Y == 2
#define bsg_noc_ybits 2
#elif bsg_routers_Y == 3
#define bsg_noc_ybits 2
#elif bsg_routers_Y == 4
#define bsg_noc_ybits 3
#elif bsg_routers_Y == 5
#define bsg_noc_ybits 3
#elif bsg_routers_Y == 6
#define bsg_noc_ybits 3
#elif bsg_routers_Y == 7
#define bsg_noc_ybits 3
#elif bsg_routers_Y == 8
#define bsg_noc_ybits 4
#elif bsg_routers_Y == 9
#define bsg_noc_ybits 4
#elif bsg_routers_Y == 16
#define bsg_noc_ybits 5
#elif bsg_routers_Y == 20
#define bsg_noc_ybits 5
#elif bsg_routers_Y == 25
#define bsg_noc_ybits 5
#elif bsg_routers_Y == 31
#define bsg_noc_ybits 5
#else
#error Unsupported bsg_routers_Y
#endif

//------------------------------------------------------
// 2.Tile Address Mapping Configuation
//------------------------------------------------------
#define MAX_X_CORD_BITS                 6
#define MAX_Y_CORD_BITS                 6

#define X_CORD_SHIFTS                   (EPA_ADDR_BITS)
#define Y_CORD_SHIFTS                   (X_CORD_SHIFTS + MAX_X_CORD_BITS)

#define REMOTE_EPA_PREFIX               0x1
#define REMOTE_EPA_MASK_BITS            (32 - EPA_ADDR_BITS - MAX_X_CORD_BITS - MAX_Y_CORD_BITS) 
#define REMOTE_EPA_MASK                 ((1<<REMOTE_EPA_MASK_BITS)-1)
#define REMOTE_EPA_MASK_SHIFTS          (Y_CORD_SHIFTS + MAX_Y_CORD_BITS)


#if (bsg_noc_xbits + bsg_noc_ybits + EPA_ADDR_BITS) > 30
#error Unsupported address configuration
#endif
//------------------------------------------------------
// 3. Basic Remote Pointers Definition
//------------------------------------------------------
// Remote EPA = {01, y_cord, x_cord, addr }
// DRAM Addr  = {1 addr                   }
//------------------------------------------------------

#define bsg_remote_addr_bits            EPA_ADDR_BITS 
#define bsg_remote_ptr(x,y,local_addr) ((bsg_remote_int_ptr) (   (REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS) \
                                                               | ((y) << Y_CORD_SHIFTS )                     \
                                                               | ((x) << X_CORD_SHIFTS )                     \
                                                               | ((int) (local_addr)   )                     \
                                                             )                                               \
                                        )

#define bsg_dram_ptr(local_addr) (  (bsg_remote_int_ptr)  ((1<< 31) | ((int) (local_addr))  ) )

#define bsg_local_ptr( remote_addr)  (    (int) (remote_addr)                           \
                                        & (   (1 << bsg_remote_addr_bits) - 1 )         \
                                     )

#define bsg_tilegroup_ptr(lc_sh,index)	( bsg_remote_ptr( ((index)%BSG_TILE_GROUP_X_DIM) , (((index)/BSG_TILE_GROUP_X_DIM)%BSG_TILE_GROUP_Y_DIM) ,(&((lc_sh)[((index)/BSG_TILE_GROUP_Y_DIM)]))) )

#define bsg_io_mutex_ptr(local_addr)  bsg_remote_ptr( IO_X_INDEX, bsg_tiles_Y, (local_addr))  
#endif
