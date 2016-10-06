#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_token_queue.h"
/*How many tiles will be actived */
const int num_act_tiles = 2;

float input1[2][16] = { 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0,9.0, 10.0,\
                      11.0,12.0,13.0,14.0,15.0,16.0,\
                       1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0,9.0, 10.0,\
                      11.0,12.0,13.0,14.0,15.0,16.0};

float input2[2][16] = { 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8,0.9, 1.0,\
                        1.1, 1.2, 1.3, 1.4, 1.5, 1.6,\
                        0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8,0.9, 1.0,\
                        1.1, 1.2, 1.3, 1.4, 1.5, 1.6};

float output[2][16];

float expect[2][16]={1.1, 2.2, 3.3, 4.4, 5.5, 6.6, 7.7, 8.8, 9.9, 11,\
                    12.1, 13.2,14.3,15.4,16.5,17.6,
                     1.1,  2.2, 3.3, 4.4, 5.5, 6.6, 7.7, 8.8, 9.9, 11,\
                    12.1, 13.2,14.3,15.4,16.5,17.6};

int   done[2]={0};


int main(int argc, char *argv[])
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);

  unsigned int * int_output_p = (unsigned int *) output;
  unsigned int * int_expect_p = (unsigned int *) expect;
  int i=0,error=0;

  if( id < num_act_tiles){

    for(i=0; i<16; i++)
        output[id][i] = input1[id][i] + input2[id][i];


    //Check the result
    for(i=0; i<16; i++)
        if( expect[id][i] != output[id][i] ){
            error= 1;
            break;
        } 
    if( error ){
        bsg_remote_ptr_io_store(0x0, 0x0, 0x44444444 );
        for(i=0;i<16;i++)
            bsg_remote_ptr_io_store(0x0, 0x0, int_output_p[id*16 +i] );
            bsg_remote_ptr_io_store(0x0, 0x0, 0x11111111 );
            bsg_remote_ptr_io_store(0x0, 0x0, int_expect_p[id*16+ i] );
    }else{
        bsg_remote_ptr_io_store(0x0, 0x0, 0x0 );
    }
 
   /*The tile0 waits until other tiles finished */ 
   if(id==0){
        for(i=1; i< num_act_tiles; i++)
            bsg_wait_while((bsg_lr( done + i ) ==0 ) && (bsg_lr_aq( done + i)==0) );
        bsg_finish();
    }else{
       bsg_remote_store(0,0, done+id,1) ;
    } 

  }//end of if(id < nun_act_tiles)

  bsg_wait_while(1);
}

