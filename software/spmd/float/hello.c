
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "float_common.h"
// these are private variables
// we do not make them volatile
// so that they may be cached

float input[N]   = {1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0,9.0,10.0};

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

    load_store_test(input);
    move_test(input);
    bypass_alu_fpi_test(input);
    bypass_fpi_fpi_test(input);
    bypass_fpi_alu_test(input);
    cvt_sgn_class_test();
    //fam_test(input);
    //stall_fam_fpi_test(input);
    fcsr_test(input);

    bsg_finish();
  }

  bsg_wait_while(1);
}

