#ifndef _BSG_MANYCORE_H
#define _BSG_MANYCORE_H

#include "bsg_manycore_arch.h"

#ifdef __cplusplus
extern "C"{
#endif

int bsg_printf(const char *fmt, ...);

#ifdef __cplusplus
}
#endif




// remote pointer types
typedef volatile int   *bsg_remote_int_ptr;
typedef volatile float   *bsg_remote_float_ptr;
typedef volatile unsigned char  *bsg_remote_uint8_ptr;
typedef volatile unsigned short  *bsg_remote_uint16_ptr;
typedef volatile unsigned *bsg_remote_uint32_ptr;
typedef volatile void *bsg_remote_void_ptr;

#define bsg_remote_flt_store(x,y,local_addr,val) do { *(bsg_remote_flt_ptr((x),(y),(local_addr))) = (float) (val); } while (0)
#define bsg_remote_flt_load(x,y,local_addr,val)  do { val = *(bsg_remote_flt_ptr((x),(y),(local_addr))) ; } while (0)

#define bsg_remote_store(x,y,local_addr,val) do { *(bsg_remote_ptr((x),(y),(local_addr))) = (int) (val); } while (0)
#define bsg_remote_load(x,y,local_addr,val)  do { val = *(bsg_remote_ptr((x),(y),(local_addr))) ; } while (0)

#define bsg_global_store(x,y,local_addr,val) do { *(bsg_global_ptr((x),(y),(local_addr))) = (int) (val); } while (0)
#define bsg_global_load(x,y,local_addr,val)  do { val = *(bsg_global_ptr((x),(y),(local_addr))) ; } while (0)

#define bsg_global_float_store(x,y,local_addr,val) do { *(bsg_global_float_ptr((x),(y),(local_addr))) = (float) (val); } while (0)
#define bsg_global_float_load(x,y,local_addr,val)  do { val = *(bsg_global_float_ptr((x),(y),(local_addr))) ; } while (0)

#define bsg_global_pod_store(px,py,x,y,local_addr,val) do { *(bsg_global_pod_ptr(px,py,(x),(y),(local_addr))) = (int) (val); } while (0)
#define bsg_global_pod_load(px,py,x,y,local_addr,val)  do { val = *(bsg_global_pod_ptr(px,py,(x),(y),(local_addr))) ; } while (0)

#define bsg_dram_store(dram_addr,val) do { *(bsg_dram_ptr((dram_addr))) = (int) (val); } while (0)
#define bsg_dram_load(dram_addr,val)  do { val = *(bsg_dram_ptr((dram_addr))) ; } while (0)

#define bsg_host_dram_store(addr, val) do {*(bsg_host_dram_ptr((addr))) = (int) (val);} while (0)
#define bsg_host_dram_load(addr, val) do { val = *(bsg_host_dram_ptr((addr)));} while (0)

#define bsg_tile_group_shared_mem(type,lc_sh,size) type lc_sh[((size + ((bsg_tiles_X * bsg_tiles_Y) -1))/(bsg_tiles_X * bsg_tiles_Y))]
#define bsg_tile_group_shared_load(type,lc_sh,index,val) (  (val) = *(bsg_tile_group_shared_ptr(type,(lc_sh),(index)))	)
#define bsg_tile_group_shared_load_direct(type,lc_sh,index) (*(bsg_tile_group_shared_ptr(type,(lc_sh),(index))))
#define bsg_tile_group_shared_store(type,lc_sh,index,val) (  *(bsg_tile_group_shared_ptr(type,(lc_sh),(index))) = (val)	)


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

// Static, inline functions for starting and stopping the PC profiler
static inline void bsg_pc_profiler_start()
{
        __asm__ __volatile__ ("csrs mie, %0": : "r" (0x20000));
        // Enable interrupts if not already enabled; One instruction overhead if interrupts were already enabled
        __asm__ __volatile__ ("csrs mstatus, %0" : : "r" (0x8));
}
static inline void bsg_pc_profiler_end()
{
        // Disable trace interupts; Other interrupts might still be active so don't clear mstatus interrupt enable bit
        __asm__ __volatile__ ("csrc mie, %0": : "r" (0x20000));
}

#define bsg_putchar( c )       do {  bsg_remote_uint8_ptr ptr = (bsg_remote_uint8_ptr) bsg_remote_ptr_io(IO_X_INDEX,0xEADC); *ptr = c; } while(0)
#define bsg_putchar_err( c )       do {  bsg_remote_uint8_ptr ptr = (bsg_remote_uint8_ptr) bsg_remote_ptr_io(IO_X_INDEX,0xEEE0); *ptr = c; } while(0)

#define bsg_heartbeat_init()       do {  bsg_remote_int_ptr ptr = bsg_remote_ptr_io(IO_X_INDEX,0xBEA0); *ptr = 0; } while(0)
#define bsg_heartbeat_iter( itr )       do {  bsg_remote_int_ptr ptr = bsg_remote_ptr_io(IO_X_INDEX,0xBEA4); *ptr = itr; } while(0)
#define bsg_heartbeat_end()       do {  bsg_remote_int_ptr ptr = bsg_remote_ptr_io(IO_X_INDEX,0xBEA8); *ptr = 0; } while(0)

static inline void bsg_print_int(int i)
{
        bsg_remote_int_ptr ptr = (bsg_remote_int_ptr)bsg_remote_ptr_io(IO_X_INDEX,0xEAE0);
        *ptr = i;
}

static inline void bsg_print_unsigned(unsigned u)
{
        bsg_remote_uint32_ptr ptr = (bsg_remote_uint32_ptr)bsg_remote_ptr_io(IO_X_INDEX,0xEAE4);
        *ptr = u;
}

static inline void bsg_print_hexadecimal(unsigned u)
{
        bsg_remote_uint32_ptr ptr = (bsg_remote_uint32_ptr)bsg_remote_ptr_io(IO_X_INDEX,0xEAE8);
        *ptr = u;
}

static inline void bsg_print_float(float f)
{
        bsg_remote_float_ptr ptr = (bsg_remote_float_ptr)bsg_remote_ptr_io(IO_X_INDEX,0xEAEC);
        *ptr = f;
}
static inline void bsg_print_float_scientific(float f)
{
        bsg_remote_float_ptr ptr = (bsg_remote_float_ptr)bsg_remote_ptr_io(IO_X_INDEX,0xEAF0);
        *ptr = f;
}

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

inline int bsg_li(int constant_val) { int result; asm("li %0, %1" : "=r"(result) : "i"(constant_val)); return result; }
inline int bsg_div(int a, int b)  { int result; __asm__ __volatile__("divu %0,%1,%2" : "=r"(result) : "r" (a), "r" (b)); return result; }
inline int bsg_mulu(int a, int b) { int result; __asm__ __volatile__("mul %0,%1,%2" : "=r"(result) : "r" (a), "r" (b)); return result; }


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


// These functions are a simple way to issue pre-fetch commands to the
// caches.  amo prefetch should not be used in practice since it marks
// the cache line as dirty. However, it is a great way to verify that
// preloads are accomplishing their goal; if all data is prefetched
// correctly with an amo operation, the load and store miss rate will
// go to 0.
inline void bsg_amo_prefetch(int * ptr){ asm volatile ("amoor.w x0, x0, 0(%[p])": : [p] "r" (ptr));}
// Verify behavioral correctness with amo prefetch, then replace with
// lw prefetch:
inline void bsg_lw_prefetch(int * ptr){ asm volatile ("lw x0, 0(%[p])": : [p] "r" (ptr));}
        
#define bsg_commit_stores() do { bsg_fence(); /* fixme: add commit stores instr */  } while (0)

// This micros are used to print the definiations in manycore program at compile time.
// Useful for other program to the get the manycore configurations, like the number of tiles, buffer size etc.
#define bsg_VALUE_TO_STRING(x) #x
#define bsg_VALUE(x) bsg_VALUE_TO_STRING(x)
#define bsg_VAR_NAME_VALUE(var) "MANYCORE_EXPORT #define " #var " "  bsg_VALUE(var)

//------------------------------------------------------
// Utility macros to use non-blocking loads
//------------------------------------------------------

// Pointers to remote locations (non-scratchpad) could be qualified
// with bsg_attr_remote to tell the compiler to assign a remote
// address space to the data pointed by those pointers. Latencies of
// memory accesses from those pointers would be considered as 20 cycles.
// `bsg_attr_remote` acts as a type qualifier for pointers and globals,
// and `bsg_attr_remote float* foo;` essentially declares foo as
// `bsg_attr_remote float*` type. Compiler assumes that loads from `foo`
// would have 20 cycle latency on average.
#ifdef __clang__
#define bsg_attr_remote __attribute__((address_space(1)))
#elif defined(__GNUC__) && !defined(__cplusplus)
#define bsg_attr_remote __remote
#else
#define bsg_attr_remote
#endif

// This macro is to protect the code from uncertainity with
// restrict/__restrict/__restrict__. Apparently some Newlib headers
// define __restrict as nothing, but __restrict__ seems to work. Hence,
// we use bsg_attr_noalias as our main way to resolve pointer alaising
// and possibly in the future, we could have `#ifdef`s here to make sure
// we use the right one under each circumstance.
#define bsg_attr_noalias __restrict__

// Unrolling pragma is slightly different for GCC and Clang. We define
// the wrapper macro `bsg_unroll` to automatically select the right pragma.
// Using this, a loop can be unrolled like this:
//
// bsg_unroll(16) for(size_t idx = start; idx < end; idx++) {
//   ...
// }
#define PRAGMA(x) _Pragma(#x)
#ifdef __clang__
#define bsg_unroll(n) PRAGMA(unroll n)
#else
#define bsg_unroll(n) PRAGMA(GCC unroll n)
#endif


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

//Macros for triggering saif generation
#define bsg_saif_start() bsg_global_store(IO_X_INDEX, IO_Y_INDEX,0xFFF0,0)
#define bsg_saif_end()   bsg_global_store(IO_X_INDEX, IO_Y_INDEX,0xFFF4,0)

#define bsg_nonsynth_saif_start() asm volatile ("addi zero,zero,1")
#define bsg_nonsynth_saif_end() asm volatile ("addi zero,zero,2")

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
