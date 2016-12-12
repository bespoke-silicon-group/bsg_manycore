/******************************************************************************
 *  The producer -- consumer scenario 
 *
 *  The cores are numbered from 0 - (tile_X*tile_Y-1),  core i sends a data vector 
 *  to i+1. Each core process the vector and sends the data to next core.
 *
 *  The processing time can vary base on configuration
 *
 * +--------------+                 +------------+
 * |              |                 |            |
 * |              |  req_num        |            |
 * |              | +----------->   |            |
 * |              |                 |            |
 * |   Producer   |                 | Consumer   |
 * |              |                 |            |
 * |              |  ack_num        |            |
 * |              | <-----------+   |            |
 * |              |                 |            |
 * +--------------+                 +------------+
 *  1. Loop_start:
 *  2.      Wait req_num to change
 *  2.      remote store data to the next core
 *  3.      Additional delay cycles.
 *  4. Loop_end: 
*****************************************************************************/
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

//shall we need the flow control ?
#define NEED_ACK
//additional cycles between each round
#define DELAY_CYCLE 0
//how many rounds we want to run ?
#define MAX_ROUND_NUM 16 

//the vector length 
#define VEC_LEN   8 

//The requst number, while will updated by remote store
int req_num     = 0;
//local round number, updated by local processor
int round_num   = 0; 
//the backward ack to notify sender that the data has been processed.
int ack_num     = 0;

//the vector data, two pools run in round robin manner
int vect1[VEC_LEN] = {0};



//////////////////////////////////////////////////////////////////////////////////////////
//the process will wait until the specified memory address was written with specific value
int spin_cond(int * ptr,  int cond ) {
    int tmp; 
    while(1){
        tmp = bsg_lr( ptr );
        if( tmp == cond ) return 0;  //the data is ready, TODO:shall we clear the reservation?
        else{
            tmp = bsg_lr_aq( ptr );  //stall until somebody clear the reservation

            //Used for debug, print the recieved value
            // bsg_remote_ptr_io_store(bsg_x, &tmp, tmp);

            if( tmp == cond ) return 0; //return if data is expected, otherwise retry
        }
    }
}

//////////////////////////////////////////////////////////////////////////////////////////
//A delay function 
inline void spin_uncond(int cycles){
    do{
     __asm__ __volatile__ ("nop"  ); 
    }while( ( cycles --) > 0);
}

//////////////////////////////////////////////////////////////////////////////////////////
//code runs on processor 
void proc( int id ){
   int i; 

   //get the (x,y) of prevoius and next core 
   int next_x, next_y;
   int prev_x, prev_y;
    
   next_x = bsg_id_to_x(id+1);
   next_y = bsg_id_to_y(id+1);

   prev_x = bsg_id_to_x(id-1);
   prev_y = bsg_id_to_y(id-1);
/*    
   if( id < (bsg_tiles_X * bsg_tiles_Y -1) ){
     bsg_remote_ptr_io_store( bsg_x, &next_x , next_x);
     bsg_remote_ptr_io_store( bsg_x, &next_y , next_y);
    }
   if( id > 0  ){
     bsg_remote_ptr_io_store( bsg_x, &prev_x , prev_x);
     bsg_remote_ptr_io_store( bsg_x, &prev_y , prev_y);
   }
 */ 
   while( round_num < MAX_ROUND_NUM) {
        //wait data is ready
        if( id !=0 ){
            spin_cond(&req_num,  round_num+1 ) ;
        } 

        //increase the round number
        round_num ++;

        //send the vect data 
        if( id != (bsg_tiles_X * bsg_tiles_Y -1) ){
            for( i=0; i< VEC_LEN; i++ )
                bsg_remote_store(next_x, next_y, &vect1, vect1[i]);

            //notify next core the data is ready
            bsg_remote_store(next_x, next_y, &req_num, round_num); 

        //last core prints the round number
        }else{
            bsg_remote_ptr_io_store( bsg_x, &round_num , round_num );
        }

        //send back the ack
        #ifdef NEED_ACK
        if( id !=0 ) bsg_remote_store(prev_x, prev_y, &ack_num,  round_num ) ;
        #endif

        //delay for a specifc period
        spin_uncond( DELAY_CYCLE );        

        //wait the ack
        #ifdef NEED_ACK
        if( id != (bsg_tiles_X * bsg_tiles_Y -1) )
            spin_cond(&ack_num,  round_num ) ;
        #endif
    };
}


////////////////////////////////////////////////////////////////////
int main()
{
  int i;

  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);
  if( id == 0) {
        //initial the data 
        for( i =0; i< VEC_LEN; i++){
           vect1[i]  = i; 
        }
   }

  proc( id );

  if( id == ( bsg_tiles_X * bsg_tiles_Y -1 ) ) bsg_finish();
    
  bsg_wait_while(1);
}

