
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bypass_common.h"
// these are private variables
// we do not make them volatile
// so that they may be cached

unsigned int input[N]   = {0x1, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa};

int print_value( unsigned int *p){
    int i;
    for(i=0; i<N; i++)
        bsg_remote_ptr_io_store(0,0x0,p[i]);
}


///////////////////////////////////////////////////////
int main()
{
  bsg_set_tile_x_y();

  if(bsg_x == 0 && bsg_y == 0){

    bypass_core_test(input);
    bsg_finish();
  }

  bsg_wait_while(1);
}

