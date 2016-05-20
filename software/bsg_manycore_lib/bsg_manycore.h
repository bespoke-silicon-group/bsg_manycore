#ifndef _BSG_MANYCORE_H
#define _BSG_MANYCORE_H

typedef volatile int   *bsg_remote_int_ptr;
typedef volatile unsigned char  *bsg_remote_uint8_ptr;
typedef volatile unsigned short  *bsg_remote_uint16_ptr;
typedef volatile void *bsg_remote_void_ptr;


#ifndef bsg_tiles_X
#error bsg_tiles_X must be defined
#endif

#ifndef bsg_tiles_Y
#error bsg_tiles_Y must be defined
#endif

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
#elif
#error Unsupported bsg_tiles_X
#endif

#if bsg_tiles_Y == 1
#define bsg_noc_ybits 1
#elif bsg_tiles_Y == 2
#define bsg_noc_ybits 2
#elif bsg_tiles_Y == 3
#define bsg_noc_ybits 2
#elif bsg_tiles_Y == 4
#define bsg_noc_ybits 3
#elif bsg_tiles_Y == 5
#define bsg_noc_ybits 3
#elif bsg_tiles_Y == 6
#define bsg_noc_ybits 3
#elif bsg_tiles_Y == 7
#define bsg_noc_ybits 3
#elif bsg_tiles_Y == 8
#define bsg_noc_ybits 4
#elif
#error Unsupported bsg_tiles_Y
#endif



// format of remote address is:
// {1, y_offs, x_offs, addr }

#define bsg_remote_addr_bits (31-bsg_noc_xbits-bsg_noc_ybits)
#define bsg_remote_ptr(x,y,local_addr) ((bsg_remote_int_ptr) ( (1<<31)                                     \
                                                               | ((y) << (31-(bsg_noc_ybits)))             \
                                                               | ((x) << (31-bsg_noc_xbits-bsg_noc_ybits)) \
                                                               | ((int) (local_addr))                      \
                                                             )                                             \
                                        )

#define bsg_remote_store(x,y,local_addr,val) do { *(bsg_remote_ptr((x),(y),(local_addr))) = (int) (val); } while (0)

#define bsg_remote_store_uint8(x,y,local_addr,val)  do { *((bsg_remote_uint8_ptr)  (bsg_remote_ptr((x),(y),(local_addr)))) = (unsigned char) (val); } while (0)
#define bsg_remote_store_uint16(x,y,local_addr,val) do { *((bsg_remote_uint16_ptr) (bsg_remote_ptr((x),(y),(local_addr)))) = (unsigned short) (val); } while (0)

#define bsg_remote_control_store(x,y,local_addr,val) bsg_remote_store((x),(y), (1 << (bsg_remote_addr_bits-1))+(local_addr),(val))
#define bsg_remote_unfreeze(x,y) bsg_remote_control_store((x),(y),0,0)
#define bsg_remote_freeze(x,y)   bsg_remote_control_store((x),(y),0,1)

// remote loads unsupported
//#define bsg_remote_load(x,y,local_addr) (*(bsg_remote_ptr((x),(y),(local_addr))))

#define bsg_remote_ptr_io(x,local_addr) bsg_remote_ptr((x),bsg_tiles_Y,(local_addr))
#define bsg_remote_ptr_io_store(x,local_addr,val) do { *(bsg_remote_ptr_io((x),(local_addr))) = (int) (val); } while (0)

// see bsg_nonsynth_manycore_monitor for secret codes
#define bsg_finish()       do {  bsg_remote_int_ptr ptr = bsg_remote_ptr_io(0,0xDEAD0); *ptr = ((bsg_y << 16) + bsg_x); while (1); } while(0)
#define bsg_print_time()   do {  bsg_remote_int_ptr ptr = bsg_remote_ptr_io(0,0xDEAD4); *ptr = ((bsg_y << 16) + bsg_x); } while(0)

#define bsg_id_to_x(id)    (id % bsg_tiles_X)
#define bsg_id_to_y(id)    (id / bsg_tiles_X)
#define bsg_x_y_to_id(x,y) (bsg_tiles_X*y + x)
#define bsg_num_tiles (bsg_tiles_X*bsg_tiles_Y)

// later, we can add some mechanisms to save power
#define bsg_wait_while(cond) do {} while ((cond))

#define bsg_volatile_access(var)        (*((bsg_remote_int_ptr) (&(var))))
#define bsg_volatile_access_uint16(var) (*((bsg_remote_uint16_ptr) (&(var))))
#define bsg_volatile_access_uint8(var)  (*((bsg_remote_uint8_ptr) (&(var))))

// prevents compiler from reordering memory operations across
// this line in the code
// see http://preshing.com/20120625/memory-ordering-at-compile-time/
// see also atomic_signal_fence(std::memory_order_seq_cst) for C11
//
#define bsg_compiler_memory_barrier() asm volatile("" ::: "memory")

#define bsg_commit_stores() do { /* fixme: add commit stores instr */  bsg_compiler_memory_barrier() } while (0)

#endif
