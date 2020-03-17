/**
 *    bsg_manycore_gather_scatter.h
 *
 *
 */


#include "bsg_manycore.h"
#include "bsg_mutex.h"

#define GS_CSR_OFFSET       0x20000
#define GS_RUN_ADDR         ((0<<2) | GS_CSR_OFFSET)
#define GS_ACCESS_LEN_ADDR  ((1<<2) | GS_CSR_OFFSET)
#define GS_STRIDE_ADDR      ((2<<2) | GS_CSR_OFFSET)
#define GS_EVA_BASE_ADDR    ((3<<2) | GS_CSR_OFFSET)

// Lock gather-scatter.
// x: x-cordinate of gather-scatter.
// y: y-cordinate of gather-scatter.
void bsg_manycore_gs_lock(int x, int y)
{
  bsg_mutex_ptr gs_lock = bsg_remote_ptr(x,y,0);
  bsg_mutex_lock(gs_lock);
}

// Unlock gather-scatter.
// x: x-cordinate of gather-scatter.
// y: y-cordinate of gather-scatter.
void bsg_manycore_gs_unlock(int x, int y)
{
  bsg_mutex_ptr gs_lock = bsg_remote_ptr(x,y,0);
  bsg_mutex_unlock(gs_lock);
}

// helper function
// x: x-cordinate of gather-scatter.
// y: y-cordinate of gather-scatter.
// eva_base: EVA base address of gather/scatter op.
// stride: Access stride in unit of words
// access_len: number of words accessed per gather/scatter op.
// scatter_not_gather: 1=scatter, 0=gather. 
void bsg_manycore_gs_helper(int x, int y, int* eva_base, int stride,
  int access_len, int* reserve_addr, int scatter_not_gather)
{
  // set access len
  bsg_global_store(x, y, GS_ACCESS_LEN_ADDR, access_len);

  // set stride
  bsg_global_store(x, y, GS_STRIDE_ADDR, stride);

  // set EVA base
  bsg_global_store(x, y, GS_EVA_BASE_ADDR, eva_base);

  // hit run button
  bsg_global_store(x, y, GS_RUN_ADDR, (scatter_not_gather<<31) | (int) reserve_addr);

  // go to sleep.
  *reserve_addr = 0;
  bsg_wait_local_int(reserve_addr, 1);
}

// Gather
void bsg_manycore_gs_gather(int x, int y, int* eva_base, int stride, int access_len, int* reserve_addr)
{
  bsg_manycore_gs_helper(x,y,eva_base,stride,access_len,reserve_addr,0);
}

// Scatter
void bsg_manycore_gs_scatter(int x, int y, int* eva_base, int stride, int access_len, int* reserve_addr)
{
  bsg_manycore_gs_helper(x,y,eva_base,stride,access_len,reserve_addr,1);
}


