//====================================================================
// bsg_dram_loopback.c
// 05/01/2018, shawnless.xie@gmail.com
//====================================================================
// This program will write and then read data from dram
//

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define VECTOR_LEN        4
#define DATA_VECT         { 0x40000000, 0x00300000, 0x00002000, 0x00000001}
#define ADDR_VECT         { 128+3*4   , 128+2*4   , 128+1*4   , 128 + 0*4 }

#define DRAM_X_CORD       1
#define DRAM_Y_CORD       1

const int  data_vect[VECTOR_LEN] = DATA_VECT;
const int  addr_vect[VECTOR_LEN] = ADDR_VECT;

int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);

  int volatile *dram_ptr;
  int volatile *io_ptr = bsg_remote_ptr( 0, 1, 0);

  if (id == 0) {
        //write dram
        for( int i=0; i< VECTOR_LEN; i++){
                dram_ptr  = bsg_remote_ptr(DRAM_X_CORD,  DRAM_Y_CORD,   ( & addr_vect[ i ])  );
                *dram_ptr = data_vect [i]       ;
        }
       //read dram and check the result
        int read_value, error=0;
        for( int j= VECTOR_LEN-1 ; j>=0 ; j--){
                dram_ptr = bsg_remote_ptr(DRAM_X_CORD,  DRAM_Y_CORD,   ( & addr_vect[ j ]) );
                read_value = * dram_ptr;

                *io_ptr = read_value;

                if( read_value != data_vect[ j ] ){
                        error =1 ;
                        break    ;
                }
        }
       //finish the program and print the check result
      if( error == 1) { bsg_fail();     }
      else            { bsg_finish();   }
  }

  bsg_wait_while(1);
}
