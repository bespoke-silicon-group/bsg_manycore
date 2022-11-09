#ifndef _BSG_MANYCORE_ARCH_H
#define _BSG_MANYCORE_ARCH_H

//------------------------------------------------------
// X/Y dimention setting/Checking.
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

#if ( bsg_tiles_Y ) > (bsg_global_Y )
#error bsg_tiles_Y is greater than bsg_global_Y
#endif


//------------------------------------------------------
// Basic EVA Format Definition
//------------------------------------------------------
// Global EPA = {01YY_YYYY_YXXX_XXXX_PPPP_PPPP_PPPP_PPPP}
// Remote EPA = {001Y_YYYY_XXXX_XXPP_PPPP_PPPP_PPPP_PPPP}
// DRAM Addr  = {1PPP_PPPP_PPPP_PPPP_PPPP_PPPP_PPPP_PPPP}
//------------------------------------------------------
#define GLOBAL_EPA_WIDTH      16
#define GLOBAL_X_CORD_WIDTH   7
#define GLOBAL_Y_CORD_WIDTH   7
#define GLOBAL_X_CORD_SHIFT   (GLOBAL_EPA_WIDTH)
#define GLOBAL_Y_CORD_SHIFT   (GLOBAL_X_CORD_SHIFT+GLOBAL_X_CORD_WIDTH)
#define GLOBAL_PREFIX_SHIFT   (GLOBAL_Y_CORD_SHIFT+GLOBAL_Y_CORD_WIDTH)

#define REMOTE_EPA_WIDTH      18
#define REMOTE_X_CORD_WIDTH   6
#define REMOTE_Y_CORD_WIDTH   5
#define REMOTE_X_CORD_SHIFT   (REMOTE_EPA_WIDTH)
#define REMOTE_Y_CORD_SHIFT   (REMOTE_X_CORD_SHIFT+REMOTE_X_CORD_WIDTH)
#define REMOTE_PREFIX_SHIFT   (REMOTE_Y_CORD_SHIFT+REMOTE_Y_CORD_WIDTH)

#define DRAM_PREFIX_SHIFT     31


// The Network CSR Addr configurations
#define CSR_BASE_ADDR   (1<<(REMOTE_EPA_WIDTH-1))
#define CSR_FREEZE      0x0
#define CSR_TGO_X       0x4
#define CSR_TGO_Y       0x8


// tile-group address pointer 
#define bsg_remote_ptr(x,y,local_addr) \
  ((bsg_remote_int_ptr) ( (1 << REMOTE_PREFIX_SHIFT)   \
                        | ((y) << REMOTE_Y_CORD_SHIFT) \
                        | ((x) << REMOTE_X_CORD_SHIFT) \
                        | ((int) local_addr)))

#define bsg_remote_flt_ptr(x,y,local_addr) \
  ((bsg_remote_float_ptr) ( (1 << REMOTE_PREFIX_SHIFT)   \
                          | ((y) << REMOTE_Y_CORD_SHIFT) \
                          | ((x) << REMOTE_X_CORD_SHIFT) \
                          | ((int) local_addr)))

#define CREATE_POINTER_BY_TYPE(type) bsg_remote_ ## type ## _ptr

#define bsg_tile_group_remote_ptr(type,x,y,local_addr) \
  ((CREATE_POINTER_BY_TYPE(type)) ( (1 << REMOTE_PREFIX_SHIFT)   \
                                  | ((y) << REMOTE_Y_CORD_SHIFT) \
                                  | ((x) << REMOTE_X_CORD_SHIFT) \
                                  | ((int) local_addr)))


// global address pointer
#define bsg_global_ptr(x,y,local_addr) \
  ((bsg_remote_int_ptr) ( (1 << GLOBAL_PREFIX_SHIFT)    \
                        | ((y) << GLOBAL_Y_CORD_SHIFT)  \
                        | ((x) << GLOBAL_X_CORD_SHIFT)  \
                        | ((int) local_addr)))


#define bsg_global_float_ptr(x,y,local_addr) \
  ((bsg_remote_float_ptr) ( (1 << GLOBAL_PREFIX_SHIFT)    \
                          | ((y) << GLOBAL_Y_CORD_SHIFT)  \
                          | ((x) << GLOBAL_X_CORD_SHIFT)  \
                          | ((int) local_addr)))


// compute pod remote pointer, corresponds to MC compute arrays for px, py
// px = pod id x
// py = pod id y
// x = subcord x
// y = subcord y
#define bsg_global_pod_ptr(px,py,x,y,local_addr) \
  ((bsg_remote_int_ptr) ( (1 << GLOBAL_PREFIX_SHIFT)    \
                        | ((((1+((py)*2))*bsg_global_Y)+(y)) << GLOBAL_Y_CORD_SHIFT)  \
                        | (((((px)+1)*bsg_global_X)+(x)) << GLOBAL_X_CORD_SHIFT)  \
                        | ((int) local_addr)))

// physical pod remote pointer, corresponds to all pods for px, py
// px = pod id x
// py = pod id y
// x = subcord x
// y = subcord y
#define bsg_global_physical_pod_ptr(px,py,x,y,local_addr) \
  ((bsg_remote_int_ptr) ( (1 << GLOBAL_PREFIX_SHIFT)    \
                        | ((((py)*bsg_global_Y)+(y)) << GLOBAL_Y_CORD_SHIFT)  \
                        | ((((px)*bsg_global_X)+(x)) << GLOBAL_X_CORD_SHIFT)  \
                        | ((int) local_addr)))

// DRAM address pointer
#define bsg_dram_ptr(local_addr) ((bsg_remote_int_ptr) ((1<<DRAM_PREFIX_SHIFT) | ((int) local_addr)))
#define bsg_host_dram_ptr(addr)  ((bsg_remote_int_ptr) ((3<<30) | ((int) (addr))))



#define bsg_local_ptr(remote_addr) ((int) (remote_addr) & ((1<<REMOTE_EPA_WIDTH)-1))



#define bsg_tile_group_shared_ptr(type,lc_sh,index) ( bsg_tile_group_remote_ptr  ( type,                                                   \
                                                                                   ((index)%bsg_tiles_X),                                  \
                                                                                   (((index)/bsg_tiles_X)%bsg_tiles_Y),                    \
                                                                                   (&((lc_sh)[((index)/(bsg_tiles_X * bsg_tiles_Y))]))) )
 
                                                    
#define bsg_io_mutex_ptr(local_addr)  bsg_global_ptr( IO_X_INDEX, IO_Y_INDEX, (local_addr))  



// Vanilla Core CSR Addr (12-bit)
#define BARCFG_CSR_ADDR 0xFC1
#define BAR_PI_CSR_ADDR 0xFC2
#define BAR_PO_CSR_ADDR 0xFC3


// Barrier Instruction
#define bsg_asm_barsend   .word 0x1000000f
#define bsg_asm_barrecv   .word 0x2000000f



#endif
