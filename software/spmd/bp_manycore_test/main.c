#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

// BlackParrot uses a 12-bit address and 4-bit device ID
#define BP_CLINT_DEV_ID 0x1
#define BP_CLINT_MIPI_ADDR 0x0
#define BP_CLINT_MIPI_EPA ((BP_CLINT_DEV_ID << (2 + 12)) | (BP_CLINT_MIPI_ADDR))

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y

#include "bsg_tile_group_barrier.h"

#ifndef NUM_ELEMENTS
#define NUM_ELEMENTS 8
#endif

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

// Reserve scratchpad area for BP to access
int data[NUM_ELEMENTS*3] __attribute__ ((section (".dmem")));

int main()
{
  /***************************
   Setup X/Y coordination
  ***************************/
  bsg_set_tile_x_y();

  /**************************************************************************
   Once BlackParrot loads all the values in all tiles, it will write N to
   the addr 0 in the data memory (N = number of elements)
   The core needs to keep polling this address to know when it can start
   computing.
  **************************************************************************/
  volatile int *dmem_addr = (int *) (0x0);
  int val;
  do {
    val = *dmem_addr;
  } while(val != NUM_ELEMENTS);

  int num_elements = *dmem_addr;

  bsg_printf("HB>>Core %d, %d in group origin=(%d,%d) says hello to BlackParrot with NUM_ELEMENTS=%d\n", \
                        __bsg_x, __bsg_y, __bsg_grp_org_x, __bsg_grp_org_y, num_elements);

  /**************************************************************************
  Load 2*num_elements number of elements from the data memory and write the
  sum to another dmem address. All the elements will be 16-bit so use the
  appropriate data type.
  **************************************************************************/
  // Use 0x8 as the base since the first 2 words are for interrupts 
  int *vec0_addr = (int *) (0x8);
  int *vec1_addr = (int *) (0x8 + 4*num_elements);
  int *vec2_addr = (int *) (0x8 + 8*num_elements);
  for(int i = 0; i < num_elements; i++) {
    *vec2_addr = *vec0_addr + *vec1_addr;
    vec0_addr += 1;
    vec1_addr += 1;
    vec2_addr += 1;
  }

  /*************************************************************************
   Wait till all the cores complete execution. Then core 0 sends a software
   interrupt to BlackParrot
  *************************************************************************/
  bsg_fence();
  bsg_tile_group_barrier(&r_barrier, &c_barrier);

  int epa, x_coord, y_coord;
  int *bp_clint_addr;
  if (__bsg_x == 0 && __bsg_y == 0) {
    bsg_printf("HB>>BlackParrot, I am done!\n");
    // Assert software interrupt
    bsg_global_pod_store(0, 0, -1, 1, BP_CLINT_MIPI_EPA, 0x1);
    bsg_fence();
    // Deassert software interrupt
    bsg_global_pod_store(0, 0, -1, 1, BP_CLINT_MIPI_EPA, 0x0);
;  }

  bsg_wait_while(1);
}

