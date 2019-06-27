#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_token_queue.h"
#include "float_common.h"
/*How many tiles will be actived */
extern float intput[N];

static float output=0.0;

static float expect=440.0;

void fmac_test(float *input)
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);

  unsigned int * int_output_p = (unsigned int *)( & output );
  unsigned int * int_expect_p = (unsigned int *)( & expect );
  int i=0,error=0;

  if( id == 0 ){

    for(i=0; i<N; i++)
        output  += input[i]*input[i] + input[i];

    //Check the result
    if( expect != output )  error= 1;
    else                    error= 0; 

    if( error ){
        bsg_remote_ptr_io_store(id, FMAC_TESTID, ERROR_CODE );
            bsg_remote_ptr_io_store(id, 0x0, *int_output_p  );
            bsg_remote_ptr_io_store(id, 0x0, 0x11111111 );
            bsg_remote_ptr_io_store(id, 0x0, *int_expect_p  );
    }else{
        bsg_remote_ptr_io_store(id, FMAC_TESTID, PASS_CODE );
        bsg_remote_ptr_io_store(id, FMAC_TESTID, *int_output_p );
    }
 
  }
}

