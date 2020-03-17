#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_gather_scatter.h"
#include "bsg_barrier.h"


#define DMEM_SIZE 1024
#define GS_X_CORD 3
#define GS_Y_CORD 5

#define N 128
#define M 16

int data0[N] __attribute__ ((section (".dram"))) = {0};
int data1[M] __attribute__ ((section (".dram"))) = {
  0,    1,    4,    9,
  16,   25,   36,   49,
  64,   81,   100,  121,
  144,  169,  196,  225
};
int reserve_lock = 0;
bsg_barrier barr = BSG_BARRIER_INIT(0,1,0,1); // 2x2 tile group

int main()
{

  bsg_set_tile_x_y();

  // Launch scatters 
  bsg_manycore_gs_lock(GS_X_CORD, GS_Y_CORD);
  // write scatter vals.
  for (int i = 0; i < N/4; i++)
  {
    int* dmem_addr = (int*) ((1<<12) | (i<<2));
    int val = __bsg_id*(N/4)+i;
    bsg_global_store(GS_X_CORD, GS_Y_CORD, dmem_addr, val); 
  }
  bsg_manycore_gs_scatter(GS_X_CORD, GS_Y_CORD, &data0[__bsg_id*(N/4)], 1, (N/4), &reserve_lock);
  bsg_manycore_gs_unlock(GS_X_CORD, GS_Y_CORD);

  // validate scatter result.
  for (int i = 0 ; i < (N/4); i++)
  {
    int val = __bsg_id*(N/4)+i;
    if (data0[val] != val) bsg_fail();
  }

  bsg_barrier_wait(&barr, 0, 0);

  // Launch Gather
  bsg_manycore_gs_lock(GS_X_CORD, GS_Y_CORD);
  bsg_manycore_gs_gather(GS_X_CORD, GS_Y_CORD, &data1[__bsg_id], 4, M/4, &reserve_lock);
  // validate gather results.
  for (int i = 0; i < M/4; i++)
  {
    int val = -1;
    int* dmem_addr =(int*) ( (1<<12) | (i<<2));
    bsg_global_load(GS_X_CORD, GS_Y_CORD, dmem_addr, val); 
    int x = __bsg_id + (i*M/4);
    if (val != x*x) {
      bsg_printf("id=%d,x=%d,y=%d,i=%d,expected=%d,actual=%d\n",__bsg_id,__bsg_x,bsg_y,i,x*x,val);
      bsg_fail();
    }
  }
  bsg_manycore_gs_unlock(GS_X_CORD, GS_Y_CORD);

  bsg_barrier_wait(&barr, 0, 0);

  // FINISH
  if (__bsg_id == 0) bsg_finish();
  bsg_wait_while(1);
}

