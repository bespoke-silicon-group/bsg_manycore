
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "mul_div_common.h"
// these are private variables
// we do not make them volatile
// so that they may be cached

int input[N]   = {1, -2, 3, -4, 5, -6, 7, -8, 9,-10};

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

    mul_div_test(input);
    bsg_finish();
  }

  bsg_wait_while(1);
}

