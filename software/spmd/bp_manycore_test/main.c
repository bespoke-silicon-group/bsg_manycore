#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

// BlackParrot uses a 12-bit address and 4-bit device ID
#define BP_CLINT_DEV_ID 0x1
#define BP_CLINT_MIPI_ADDR 0x0
#define BP_CLINT_MIPI_EPA ((BP_CLINT_DEV_ID << 12) | (BP_CLINT_MIPI_ADDR))  

#define BSG_TILE_GROUP_X_DIM bsg_tiles_X
#define BSG_TILE_GROUP_Y_DIM bsg_tiles_Y

#include "bsg_tile_group_barrier.h"

#ifndef NUM_ELEMENTS
#define NUM_ELEMENTS 8
#endif

INIT_TILE_GROUP_BARRIER(r_barrier, c_barrier, 0, bsg_tiles_X-1, 0, bsg_tiles_Y-1);

// Reserve scratchpad area for BP to access
int data[8] __attribute__ ((section (".dmem")));

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
  int *dmem_addr = (int *) (0x0);
  int val;
  do {
    val = *dmem_addr;
  } while(val != NUM_ELEMENTS);

  int num_elements = *dmem_addr;

  /**************************************************************************
  Load 2*num_elements number of elements from the data memory and write the
  sum to another dmem address. All the elements will be 16-bit so use the
  appropriate data type.
  **************************************************************************/
  // Use 0x8 as the base since the first 2 words are for interrupts 
  volatile short *vec1_addr = (short *) (0x8);
  volatile short *vec2_addr = (short *) (0x8 + num_elements);
  volatile short *vec3_addr = (short *) (0x8 + (num_elements << 1));
  for(int i = 0; i < num_elements; i++) {
    *vec3_addr = *vec1_addr + *vec2_addr;
    // The data is located at each word, but the pointers are to halfwords
    vec1_addr += 2;
    vec2_addr += 2;
    vec3_addr += 2;
  }

  /*************************************************************************
   Wait till all the cores complete execution. Then core 0 sends a software
   interrupt to BlackParrot
  *************************************************************************/
  bsg_fence();
  bsg_tile_group_barrier(&r_barrier, &c_barrier);

  if (__bsg_x == 0 && __bsg_y == 0) {
    bsg_remote_store(0, 9, BP_CLINT_MIPI_EPA, 0x1);
  }

  bsg_wait_while(1);
}

