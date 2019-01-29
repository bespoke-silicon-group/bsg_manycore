
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

/************************************************************************
 Declear an array in DRAM. 
*************************************************************************/
int data[4] __attribute__ ((section (".dram"))) = { -1, 1, 0xF, 0x80000000};

int main()
{
   int i;
  /************************************************************************
   This will setup the bsg_x and bsg_y value to the actual X/Y coordination.
   Must be called if the program uses the bsg_x and bsg_y.
  *************************************************************************/
  bsg_set_tile_x_y();

  /************************************************************************
   Basic IO outputs bsg_remote_ptr_io_store(IO_X_INDEX, Address, Value)
   Every core will outputs once.
  *************************************************************************/
  bsg_remote_ptr_io_store(IO_X_INDEX,0x1260,bsg_x);

  /************************************************************************
   Example of Using Prinf. 
   Please call printf once a time, other wise the output string will be 
   messed up.  
   A mutex in printf should release this constraint.
  *************************************************************************/
  if ((bsg_x == bsg_tiles_X-1) && (bsg_y == bsg_tiles_Y-1)) {

     bsg_printf("\nManycore>> Hello from core %d, %d.\n", bsg_x, bsg_y);
     bsg_printf("Manycore>> Values in DRAM:");
     for(i=0; i<4; i++)
        bsg_printf("%08x,",data[i]);
     bsg_printf("\n\n");

  /************************************************************************
    Terminates the Simulation
  *************************************************************************/
    bsg_finish();
  }

  bsg_wait_while(1);
}

