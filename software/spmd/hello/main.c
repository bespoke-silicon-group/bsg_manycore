
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
   This will setup the  X/Y coordination. Current pre-defined corrdinations 
   includes:
        __bsg_x         : The X cord inside the group 
        __bsg_y         : The Y cord inside the group
        __bsg_org_x     : The origin X cord of the group
        __bsg_org_y     : The origin Y cord of the group
  *************************************************************************/
  bsg_set_tile_x_y();

  /************************************************************************
   Basic IO outputs bsg_remote_ptr_io_store(IO_X_INDEX, Address, Value)
   Every core will outputs once.
  *************************************************************************/
  bsg_remote_ptr_io_store(IO_X_INDEX,0x1260,__bsg_x);

  /************************************************************************
   Example of Using Prinf. 
   A io mutex was defined for input/output node. 
   The printf will get the mutex first and then output the char stream. 
  *************************************************************************/
  if ((__bsg_x == bsg_tiles_X-1) && (__bsg_y == bsg_tiles_Y-1)) {

     bsg_printf("\nManycore>> Hello from core %d, %d in group origin=(%d,%d).\n", \
                        __bsg_x, __bsg_y, __bsg_grp_org_x, __bsg_grp_org_y);

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

