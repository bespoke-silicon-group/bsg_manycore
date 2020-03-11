#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_gather_scatter.h"


#define DMEM_SIZE 1024
#define GS_X_CORD 3
#define GS_Y_CORD 5

#define N 128

int data0[N] __attribute__ ((section (".dram"))) = {0};
int reserve_lock = 0;

int main()
{

  bsg_set_tile_x_y();
  
  bsg_printf("Hello my friends~~!\n");

  // First, acquire the lock on the gather-scatterer.
  bsg_manycore_gs_lock(GS_X_CORD, GS_Y_CORD);

  // write to DMEM.
  bsg_printf("Writing to gather-scatter DMEM...\n");
  for (int i = 0; i < DMEM_SIZE; i++)
  {
    int* dmem_addr = (int*) ((1<<12) | (i<<2));
    bsg_global_store(GS_X_CORD, GS_Y_CORD, dmem_addr, i); 
  }

  // read back from DMEM.
  bsg_printf("Reading from gather-scatter DMEM...\n");
  for (int i = 0; i < DMEM_SIZE; i++)
  {
    int val = -1;
    int* dmem_addr =(int*) ( (1<<12) | (i<<2));
    bsg_global_load(GS_X_CORD, GS_Y_CORD, dmem_addr, val); 
    if (val != i)
    {
      bsg_fail();
    }
  }

  // launch scatter
  bsg_printf("Launching scatter...\n");
  bsg_manycore_gs_scatter(GS_X_CORD, GS_Y_CORD, &data0[0], 1, N, &reserve_lock);

  // validate scatter result.
  bsg_printf("Validating scatter result...\n");
  for (int i = 0 ; i < N ; i++)
  {
    if (data0[i] != i) bsg_fail();
  }

  // Prepare for gather
  bsg_printf("Preparing for gather...\n");
  for (int i = 0; i < DMEM_SIZE; i++)
  {
    int* dmem_addr = (int*) ((1<<12) | (i<<2));
    bsg_global_store(GS_X_CORD, GS_Y_CORD, dmem_addr, 0); 
  }

  for (int i = 0; i < DMEM_SIZE; i++)
  {
    int val = -1;
    int* dmem_addr =(int*) ( (1<<12) | (i<<2));
    bsg_global_load(GS_X_CORD, GS_Y_CORD, dmem_addr, val); 
    if (val != 0)
    {
      bsg_fail();
    }
  }

  for (int i = 0; i < N; i++)
  {
    data0[i] = i*i;
  }
  
  bsg_fence();
 
  // Launch Gather
  bsg_printf("Launching gather...\n"); 
  bsg_manycore_gs_gather(GS_X_CORD, GS_Y_CORD, &data0[0], 1, N, &reserve_lock);


  // Validate gather
  bsg_printf("Validating gather result...\n");
  for (int i = 0; i < N; i++)
  {
    int val = -1;
    int* dmem_addr =(int*) ( (1<<12) | (i<<2));
    bsg_global_load(GS_X_CORD, GS_Y_CORD, dmem_addr, val); 
    if (val != i*i)
    {
      bsg_fail();
    } 
  }

  // Release the lock, so others can use.
  bsg_manycore_gs_unlock(GS_X_CORD, GS_Y_CORD);


  // FINISH
  bsg_finish();

  bsg_wait_while(1);
}

