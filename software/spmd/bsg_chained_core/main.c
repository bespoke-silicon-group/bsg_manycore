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

#ifdef ROCKET_MANYCORE

#define MANYCORE_PROG
#define MANYCORE_DST_BUF_LEN        BUF_LEN
#include "bsg_manycore_buffer.h"

#endif

extern proc_func_ptr func_array[];

//The requst number, while will updated by remote store
int valid_num[2]  ={0};

//local round number, updated by local processor
int round_num   = 0;

//the backward ack to notify sender that the data has been processed.
int ready_num[2]  ={0};

//the vector data, two pools run in round robin manner
tag_data_s buffer[2][BUF_LEN] = {0};

inline void spin_cond(int * ptr,  int cond ); 
inline void spin_uncond(int cycles);
inline void print_buff( tag_data_s * pData, int len);

//////////////////////////////////////////////////////////////////////////////////////////
//code runs on processor
void proc( int id ){
   int i, j;
   volatile tag_data_s * remote_ptr;

   //get the (x,y) of prevoius and next core
   int next_x, next_y;
   int prev_x, prev_y;

   next_x = bsg_id_to_x(id+1);
   next_y = bsg_id_to_y(id+1);

   prev_x = bsg_id_to_x(id-1);
   prev_y = bsg_id_to_y(id-1);

   //at the beginning, we notify privous core that we are ready!
   round_num++;
   if( id !=0 ) {
        bsg_remote_store(prev_x, prev_y, ready_num  ,  round_num   ) ;
        bsg_remote_store(prev_x, prev_y, ready_num+1,  round_num+1 ) ;
   }

   do {
     for( j=0; j<2; j++){ //switch from buffer 0 and buffer 1

        //wait until data is valid
        if( id !=0 ) spin_cond( (valid_num+j),  round_num ) ;

        remote_ptr = (tag_data_s *)bsg_remote_ptr( next_x, next_y, buffer[j]);

        if( id !=  (bsg_num_tiles -1) ){ //Not the last core

            //wait until buffer is ready
            if( id != (bsg_num_tiles-1) )   spin_cond( (ready_num +j),  round_num ) ;

            //run the specific process
            if( func_array[id]) ( func_array[id]( buffer[j], remote_ptr, BUF_LEN, round_num, id ) );

            //notify next core the data is valid
            bsg_remote_store( next_x, next_y, (valid_num+j), round_num );

        }else if( round_num == (MAX_ROUND_NUM-1)) { //The last core and last round
            //output the buffer content
            print_buff( buffer[j], BUF_LEN);
        }

        //delay for a specifc period
        spin_uncond( DELAY_CYCLE );

        //increase the round number and notify that one buffer is ready!
        round_num ++;
        if( round_num > MAX_ROUND_NUM )
            break;
        else if( id !=0 )
            bsg_remote_store(prev_x, prev_y, ready_num+j,  round_num+1 ) ;

      } // end of for( j=0 )
    }while( round_num <= MAX_ROUND_NUM) ;//end of while
}


////////////////////////////////////////////////////////////////////
int main()
{
  int i;

  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);

  if( id == 0) {
        //initial the data
        for( i =0; i< BUF_LEN; i++){
           buffer[0][i].tag.value  = i;
           buffer[1][i].tag.value  = i;
        }
   }

  //init_func_array( eONE_COPY_FUNCS );
  //init_func_array( eALL_PASS_FUNCS );
    init_func_array( eALL_TAG_PASS_FUNCS );

  proc( id );

  if( id == ( bsg_num_tiles  -1 ) ){
    #ifdef ROCKET_MANYCORE
        bsg_rocc_finish(& manycore_data_s);
    #else
        bsg_finish();
    #endif
  }

  bsg_wait_while(1);
}

//////////////////////////////////////////////////////////////////////////////////////////
//the process will wait until the specified memory address was written with specific value
inline void spin_cond(int * ptr,  int cond ) {
    int tmp;
    while(1){
        tmp = bsg_lr( ptr );
        if( tmp == cond ) return ;  //the data is ready, TODO:shall we clear the reservation?
        else{
            tmp = bsg_lr_aq( ptr );  //stall until somebody clear the reservation
            if( tmp == cond ) return ; //return if data is expected, otherwise retry
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
//print buffer content
inline void print_buff( tag_data_s * pData, int len){
    tag_data_s  *pTmpData;
    #ifdef ROCKET_MANYCORE
        manycore_task_s *pRocketViewTask = bsg_rocket_view_task( &manycore_data_s);
        pTmpData = (tag_data_s *)( pRocketViewTask->result );
    #else
        pTmpData = pData;
    #endif
    for( int i=0; i< len ; i ++ ){
        bsg_remote_ptr_io_store(IO_X_INDEX, &(pTmpData[i].data), pData[i].data);
    }
}
////////////////////////////////////////////////////////////////
//Print the current manycore configurations
#pragma message (bsg_VAR_NAME_VALUE( bsg_tiles_X )  )
#pragma message (bsg_VAR_NAME_VALUE( bsg_tiles_Y )  )
#pragma message (bsg_VAR_NAME_VALUE( MAX_ROUND_NUM )  )
#pragma message (bsg_VAR_NAME_VALUE( BUF_LEN )  )
