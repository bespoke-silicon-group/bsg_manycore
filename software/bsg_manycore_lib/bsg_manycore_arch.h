#ifndef _BSG_MANYCORE_ARCH_H
#define _BSG_MANYCORE_ARCH_H

//------------------------------------------------------
// 0. basic SoC definitaion
//------------------------------------------------------
#define IO_X_INDEX     (0) 
#define IO_Y_INDEX     (1) 
//in words.
#define EPA_ADDR_BITS                   18

// The CSR Addr configurations
// bsg_manycore/v/parameters.vh  for definition in RTL
#define CSR_BASE_ADDR   (1<< (EPA_ADDR_BITS-1))
#define CSR_FREEZE      0x0
#define CSR_TGO_X       0x4
#define CSR_TGO_Y       0x8
//------------------------------------------------------
// 1. X/Y dimention setting/Checking.
//------------------------------------------------------
#ifndef bsg_global_X
#error bsg_global_X must be defined
#endif

#ifndef bsg_global_Y
#error bsg_global_Y must be defined
#endif

#ifndef bsg_tiles_X
#error bsg_tiles_X must be defined
#endif

#ifndef bsg_tiles_Y
#error bsg_tiles_Y must be defined
#endif

#if ( bsg_tiles_Y + 1 ) > (bsg_global_Y )
#error bsg_tiles_Y must 1 less than bsg_global_Y
#endif

//------------------------------------------------------
// 2.Tile Address Mapping Configuation
//------------------------------------------------------
#define MAX_X_CORD_BITS                 6
#define MAX_Y_CORD_BITS                 6

#define X_CORD_SHIFTS                   (EPA_ADDR_BITS)
#define Y_CORD_SHIFTS                   (X_CORD_SHIFTS + MAX_X_CORD_BITS)

#define REMOTE_EPA_PREFIX               0x1
#define GLOBAL_EPA_PREFIX               0x1
#define REMOTE_EPA_MASK_BITS            (32 - EPA_ADDR_BITS - MAX_X_CORD_BITS - MAX_Y_CORD_BITS) 
#define REMOTE_EPA_MASK                 ((1<<REMOTE_EPA_MASK_BITS)-1)
//TODO -- MAX_Y_CORD_BITS is reduced 1 bits. 
#define REMOTE_EPA_MASK_SHIFTS          (Y_CORD_SHIFTS + MAX_Y_CORD_BITS -1)
#define GLOBAL_EPA_MASK_SHIFTS          (Y_CORD_SHIFTS + MAX_Y_CORD_BITS   )

//------------------------------------------------------
// 3. Basic Remote Pointers Definition
//------------------------------------------------------
// Global EPA = {01, y_cord, x_cord, addr }
// Remote EPA = {001,y_cord, x_cord, addr }
// DRAM Addr  = {1 addr                   }
//------------------------------------------------------

#define bsg_remote_addr_bits            EPA_ADDR_BITS 
// Used for in tile group access
#define bsg_remote_ptr(x,y,local_addr) ((bsg_remote_int_ptr) (   (REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS) \
                                                               | ((y) << Y_CORD_SHIFTS )                     \
                                                               | ((x) << X_CORD_SHIFTS )                     \
                                                               | ((int) (local_addr)   )                     \
                                                             )                                               \
                                        )

#define bsg_remote_flt_ptr(x,y,local_addr) ((bsg_remote_float_ptr) (   (REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS) \
                                                               | ((y) << Y_CORD_SHIFTS )                     \
                                                               | ((x) << X_CORD_SHIFTS )                     \
                                                               | ((int) (local_addr)   )                     \
                                                             )                                               \
                                        )

#define CREATE_POINTER_BY_TYPE(type) bsg_remote_ ## type ## _ptr

#define bsg_tile_group_remote_ptr(type,x,y,local_addr) ( (CREATE_POINTER_BY_TYPE(type)) (   (REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS)  \
                                                                                          | ((y) << Y_CORD_SHIFTS )                        \
                                                                                          | ((x) << X_CORD_SHIFTS )                        \
                                                                                          | ((int) (local_addr)   )                        \
                                                                                        )                                                  \
                                                       )



//Used for global network access
#define bsg_global_ptr(x,y,local_addr) ((bsg_remote_int_ptr) (   (GLOBAL_EPA_PREFIX << GLOBAL_EPA_MASK_SHIFTS) \
                                                               | ((y) << Y_CORD_SHIFTS )                     \
                                                               | ((x) << X_CORD_SHIFTS )                     \
                                                               | ((int) (local_addr)   )                     \
                                                             )                                               \
                                        )
#define bsg_global_float_ptr(x,y,local_addr) ((bsg_remote_float_ptr) (   (GLOBAL_EPA_PREFIX << GLOBAL_EPA_MASK_SHIFTS) \
                                                               | ((y) << Y_CORD_SHIFTS )                     \
                                                               | ((x) << X_CORD_SHIFTS )                     \
                                                               | ((int) (local_addr)   )                     \
                                                             )                                               \
                                        )
#define bsg_dram_ptr(local_addr) (  (bsg_remote_int_ptr)  ((1<< 31) | ((int) (local_addr))  ) )

#define bsg_host_dram_ptr(addr) ( (bsg_remote_int_ptr) ((3<<30) | ((int) (addr))))

#define bsg_local_ptr( remote_addr)  (    (int) (remote_addr)                           \
                                        & (   (1 << bsg_remote_addr_bits) - 1 )         \
                                     )

#define bsg_tile_group_shared_ptr(type,lc_sh,index) ( bsg_tile_group_remote_ptr  ( type,                                                   \
                                                                                   ((index)%bsg_tiles_X),                                  \
                                                                                   (((index)/bsg_tiles_X)%bsg_tiles_Y),                    \
                                                                                   (&((lc_sh)[((index)/(bsg_tiles_X * bsg_tiles_Y))]))) )
 
                                                    
#define bsg_io_mutex_ptr(local_addr)  bsg_global_ptr( IO_X_INDEX, IO_Y_INDEX, (local_addr))  
#endif
