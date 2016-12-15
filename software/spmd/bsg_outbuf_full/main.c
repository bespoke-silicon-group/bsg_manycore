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
 * |              |  valid_num      |            |
 * |              | +----------->   |            |
 * |              |                 |            |
 * |   Producer   |                 | Consumer   |
 * |              |                 |            |
 * |              |  ready_num      |            |
 * |              | <-----------+   |            |
 * |              |                 |            |
 * +--------------+                 +------------+
 *  1. Loop_start:
 *  2.      Wait valid_num to change
 *  2.      remote store data to the next core
 *  3.      Additional delay cycles.
 *  4. Loop_end: 
*****************************************************************************/
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "chained_core.h"

extern proc_func_ptr func_array[];

int round_num=0;
//the vector data, two pools run in round robin manner
int buffer[BUF_LEN] = {0};

//////////////////////////////////////////////////////////////////////////////////////////
//code runs on processor 
void proc( int id ){
   int i; 
   volatile int * remote_ptr;

   //get the (x,y) of prevoius and next core 
   int next_x, next_y;
   int prev_x, prev_y;
    
   next_x = bsg_id_to_x(id+1);
   next_y = bsg_id_to_y(id+1);

   prev_x = bsg_id_to_x(id-1);
   prev_y = bsg_id_to_y(id-1);

   //at the beginning, we notify privous core that we are ready!
   remote_ptr = bsg_remote_ptr( next_x, next_y, buffer);
   round_num++;
   do {
         if( id == 1 ) bsg_remote_ptr_io_store( bsg_x, &round_num , round_num );
         //run the specific process
         if( func_array[id]){
            func_array[id]( buffer, remote_ptr, BUF_LEN ) ;
         }
        round_num ++ ;
    }while( round_num <= MAX_ROUND_NUM) ;//end of while
}


////////////////////////////////////////////////////////////////////
int main()
{

  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);

  init_func_array( CONFIG );
  
  proc( id );

  if( id == 1 ) bsg_finish();
    
  bsg_wait_while(1);
}

