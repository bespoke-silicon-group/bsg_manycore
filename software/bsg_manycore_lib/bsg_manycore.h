#ifndef _BSG_MANYCORE_H
#define _BSG_MANYCORE_H

#include "bsg_manycore_arch.h"

int bsg_printf(const char *fmt, ...);

typedef volatile int   *bsg_remote_int_ptr;
typedef volatile float   *bsg_remote_float_ptr;
typedef volatile unsigned char  *bsg_remote_uint8_ptr;
typedef volatile unsigned short  *bsg_remote_uint16_ptr;
typedef volatile void *bsg_remote_void_ptr;

#define bsg_remote_store(x,y,local_addr,val) do { *(bsg_remote_ptr((x),(y),(local_addr))) = (int) (val); } while (0)
#define bsg_remote_load(x,y,local_addr,val)  do { val = *(bsg_remote_ptr((x),(y),(local_addr))) ; } while (0)

#define bsg_global_store(x,y,local_addr,val) do { *(bsg_global_ptr((x),(y),(local_addr))) = (int) (val); } while (0)
#define bsg_global_load(x,y,local_addr,val)  do { val = *(bsg_global_ptr((x),(y),(local_addr))) ; } while (0)

#define bsg_global_float_store(x,y,local_addr,val) do { *(bsg_global_float_ptr((x),(y),(local_addr))) = (float) (val); } while (0)
#define bsg_global_float_load(x,y,local_addr,val)  do { val = *(bsg_global_float_ptr((x),(y),(local_addr))) ; } while (0)

#define bsg_dram_store(dram_addr,val) do { *(bsg_dram_ptr((dram_addr))) = (int) (val); } while (0)
#define bsg_dram_load(dram_addr,val)  do { val = *(bsg_dram_ptr((dram_addr))) ; } while (0)

#define bsg_host_dram_store(addr, val) do {*(bsg_host_dram_ptr((addr))) = (int) (val);} while (0)
#define bsg_host_dram_load(addr, val) do { val = *(bsg_host_dram_ptr((addr)));} while (0)

#define bsg_tile_group_shared_mem(type,lc_sh,size) type lc_sh[((size + ((bsg_tiles_X * bsg_tiles_Y) -1))/(bsg_tiles_X * bsg_tiles_Y))]
#define bsg_tile_group_shared_load(lc_sh,index,val) (  (val) = *(bsg_tile_group_shared_ptr((lc_sh),(index)))	)
#define bsg_tile_group_shared_store(lc_sh,index,val) (  *(bsg_tile_group_shared_ptr((lc_sh),(index))) = (val)	)


#define bsg_remote_store_uint8(x,y,local_addr,val)  do { *((bsg_remote_uint8_ptr)  (bsg_remote_ptr((x),(y),(local_addr)))) = (unsigned char) (val); } while (0)
#define bsg_remote_store_uint16(x,y,local_addr,val) do { *((bsg_remote_uint16_ptr) (bsg_remote_ptr((x),(y),(local_addr)))) = (unsigned short) (val); } while (0)

#define bsg_remote_ptr_control(x,y, CSR_offset) bsg_remote_ptr( (x), (y), ( (CSR_BASE_ADDR) + (CSR_offset) ) )
//#define bsg_remote_unfreeze(x,y) bsg_remote_control_store((x),(y),0,0)
//#define bsg_remote_freeze(x,y)   bsg_remote_control_store((x),(y),0,1)
//deprecated
//#define bsg_remote_arb_config(x,y,value)   bsg_remote_control_store((x),(y),4,value)

// remote loads
//#define bsg_remote_load(x,y,local_addr, val) ( val = *(bsg_remote_ptr((x),(y),(local_addr))) )

#define bsg_remote_ptr_io(x,local_addr) bsg_global_ptr((x), IO_Y_INDEX,(local_addr))
#define bsg_remote_ptr_io_store(x,local_addr,val) do { *(bsg_remote_ptr_io((x),(local_addr))) = (int) (val); } while (0)
#define bsg_remote_ptr_io_load(x,local_addr,val) do { (val) = *(bsg_remote_ptr_io((x),(local_addr))) ; } while (0)

// see bsg_nonsynth_manycore_monitor for secret codes
// For 18 bits remote address, we cannot mantain the 0xDEAD0 address.
#define bsg_finish()       do {  bsg_remote_int_ptr ptr = bsg_remote_ptr_io(IO_X_INDEX,0xEAD0); *ptr = ((bsg_y << 16) + bsg_x); while (1); } while(0)

#define bsg_finish_x(x)       do {  bsg_remote_int_ptr ptr = bsg_remote_ptr_io(x,0xEAD0); *ptr = ((bsg_y << 16) + bsg_x); while (1); } while(0)
#define bsg_fail()       do {  bsg_remote_int_ptr ptr = bsg_remote_ptr_io(IO_X_INDEX,0xEAD8); *ptr = ((bsg_y << 16) + bsg_x); while (1); } while(0)
#define bsg_fail_x(x)       do {  bsg_remote_int_ptr ptr = bsg_remote_ptr_io(x,0xEAD8); *ptr = ((bsg_y << 16) + bsg_x); while (1); } while(0)
#define bsg_print_time()   do {  bsg_remote_int_ptr ptr = bsg_remote_ptr_io(IO_X_INDEX,0xEAD4); *ptr = ((bsg_y << 16) + bsg_x); } while(0)

#define bsg_putchar( c )       do {  bsg_remote_uint8_ptr ptr = (bsg_remote_uint8_ptr) bsg_remote_ptr_io(IO_X_INDEX,0xEADC); *ptr = c; } while(0)

#define bsg_id_to_x(id)    ((id) % bsg_tiles_X)
#define bsg_id_to_y(id)    ((id) / bsg_tiles_X)
#define bsg_x_y_to_id(x,y) (bsg_tiles_X*(y) + (x))
#define bsg_num_tiles (bsg_tiles_X*bsg_tiles_Y)

// later, we can add some mechanisms to save power
#define bsg_wait_while(cond) do {} while ((cond))

// load reserved; and load reserved acquire
#ifdef __clang__
inline int bsg_lr(int *p)    { int tmp; __asm__ __volatile__("lr.w    %0,%1\n" : "=r" (tmp) : "m" (*p)); return tmp; }
inline int bsg_lr_aq(int *p) { int tmp; __asm__ __volatile__("lr.w.aq %0,%1\n" : "=r" (tmp) : "m" (*p)); return tmp; }
#elif defined(__GNUC__) || defined(__GNUG__)
inline int bsg_lr(int *p)    { int tmp; __asm__ __volatile__("lr.w    %0,%1\n" : "=r" (tmp) : "A" (*p)); return tmp; }
inline int bsg_lr_aq(int *p) { int tmp; __asm__ __volatile__("lr.w.aq %0,%1\n" : "=r" (tmp) : "A" (*p)); return tmp; }
#else
#error Unsupported Compiler!
#endif

inline void bsg_fence()      { __asm__ __volatile__("fence" :::); }

#define bsg_volatile_access(var)        (*((bsg_remote_int_ptr) (&(var))))
#define bsg_volatile_access_uint16(var) (*((bsg_remote_uint16_ptr) (&(var))))
#define bsg_volatile_access_uint8(var)  (*((bsg_remote_uint8_ptr) (&(var))))

// prevents compiler from reordering memory operations across
// this line in the code
// see http://preshing.com/20120625/memory-ordering-at-compile-time/
// see also atomic_signal_fence(std::memory_order_seq_cst) for C11
//
// this is a very heavy weight operation, and generally not advised
// at least for GCC.
//

#define bsg_compiler_memory_barrier() asm volatile("" ::: "memory")

#define bsg_commit_stores() do { bsg_fence(); /* fixme: add commit stores instr */  } while (0)

// This micros are used to print the definiations in manycore program at compile time.
// Useful for other program to the get the manycore configurations, like the number of tiles, buffer size etc.
#define bsg_VALUE_TO_STRING(x) #x
#define bsg_VALUE(x) bsg_VALUE_TO_STRING(x)
#define bsg_VAR_NAME_VALUE(var) "MANYCORE_EXPORT #define " #var " "  bsg_VALUE(var)


//------------------------------------------------------
// Print stat parameters and operations
//------------------------------------------------------
#define BSG_CUDA_PRINT_STAT_ID_START        0
#define BSG_CUDA_PRINT_STAT_ID_END          1
#define BSG_CUDA_PRINT_STAT_ID_KERNEL_START 2
#define BSG_CUDA_PRINT_STAT_ID_KERNEL_END   3

#define BSG_CUDA_PRINT_STAT_TAG_WIDTH       4
#define BSG_CUDA_PRINT_STAT_TG_ID_WIDTH     14
#define BSG_CUDA_PRINT_STAT_X_WIDTH         6
#define BSG_CUDA_PRINT_STAT_Y_WIDTH         6
#define BSG_CUDA_PRINT_STAT_TYPE_WIDTH      2

#define BSG_CUDA_PRINT_STAT_TAG_TOTAL       0x0

#define BSG_CUDA_PRINT_STAT_TAG_SHIFT       (0)                                                                 // 0
#define BSG_CUDA_PRINT_STAT_TG_ID_SHIFT     (BSG_CUDA_PRINT_STAT_TAG_SHIFT   + BSG_CUDA_PRINT_STAT_TAG_WIDTH)   // 4
#define BSG_CUDA_PRINT_STAT_X_SHIFT         (BSG_CUDA_PRINT_STAT_TG_ID_SHIFT + BSG_CUDA_PRINT_STAT_TG_ID_WIDTH) // 18
#define BSG_CUDA_PRINT_STAT_Y_SHIFT         (BSG_CUDA_PRINT_STAT_X_SHIFT     + BSG_CUDA_PRINT_STAT_X_WIDTH)     // 24
#define BSG_CUDA_PRINT_STAT_TYPE_SHIFT      (BSG_CUDA_PRINT_STAT_Y_SHIFT     + BSG_CUDA_PRINT_STAT_Y_WIDTH)     // 30

#define BSG_CUDA_PRINT_STAT_TAG_MASK        ((1 << BSG_CUDA_PRINT_STAT_TAG_WIDTH) - 1)    // 0xF
#define BSG_CUDA_PRINT_STAT_TG_ID_MASK      ((1 << BSG_CUDA_PRINT_STAT_TG_ID_WIDTH) - 1)  // 0x3FFF
#define BSG_CUDA_PRINT_STAT_X_MASK          ((1 << BSG_CUDA_PRINT_STAT_X_WIDTH) - 1)      // 0x3F
#define BSG_CUDA_PRINT_STAT_Y_MASK          ((1 << BSG_CUDA_PRINT_STAT_Y_WIDTH) - 1)      // 0x3F


#define bsg_print_stat(tag) do { bsg_remote_int_ptr ptr = bsg_remote_ptr_io(IO_X_INDEX,0xd0c); *ptr = tag; } while (0)


#define bsg_cuda_print_stat_type(tag,stat_type) do {                                                              \
    int val = ( (stat_type << BSG_CUDA_PRINT_STAT_TYPE_SHIFT)                                                |    \
                (((__bsg_grp_org_y + __bsg_y) & BSG_CUDA_PRINT_STAT_Y_MASK) << BSG_CUDA_PRINT_STAT_Y_SHIFT)  |    \
                (((__bsg_grp_org_x + __bsg_x) & BSG_CUDA_PRINT_STAT_X_MASK) << BSG_CUDA_PRINT_STAT_X_SHIFT)  |    \
                ((__bsg_tile_group_id & BSG_CUDA_PRINT_STAT_TG_ID_MASK) << BSG_CUDA_PRINT_STAT_TG_ID_SHIFT)  |    \
                ((tag & BSG_CUDA_PRINT_STAT_TAG_MASK) << BSG_CUDA_PRINT_STAT_TAG_SHIFT) );                        \
    bsg_print_stat(val);                                                                                          \
} while (0)

//#define bsg_cuda_print_stat(tag)          bsg_cuda_print_stat_type(tag,BSG_CUDA_PRINT_STAT_ID_STAT)
#define bsg_cuda_print_stat_start(tag)    bsg_cuda_print_stat_type(tag,BSG_CUDA_PRINT_STAT_ID_START)
#define bsg_cuda_print_stat_end(tag)      bsg_cuda_print_stat_type(tag,BSG_CUDA_PRINT_STAT_ID_END)
#define bsg_cuda_print_stat_kernel_start() bsg_cuda_print_stat_type(BSG_CUDA_PRINT_STAT_TAG_TOTAL,BSG_CUDA_PRINT_STAT_ID_KERNEL_START)
#define bsg_cuda_print_stat_kernel_end()   bsg_cuda_print_stat_type(BSG_CUDA_PRINT_STAT_TAG_TOTAL,BSG_CUDA_PRINT_STAT_ID_KERNEL_END)


#endif
