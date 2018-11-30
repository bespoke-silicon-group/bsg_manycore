/******************************************************************************
 *  The Load Reserved and Load Reserved Acquire should be used in pair for low
 *  power inter-processor synchronization
 *
 *  In follow scenarios,  we are waiting for a variable to change to the value 7
 *  , by another core. The following sequence is used:  
 * ****************************************************************************
 * li $cmp, 7
 *
 * top:
 * lr.w $val, ptr       // load ptr, and set reservation on ptr
 * beq $val,$cmp, out   // if the value == 7, we exit loop
 * lr.w.aq $val, ptr    // otherwise, stall until reservation is cleared, then load ptr
 *                      // the reservation is cleared if somebody writes the address
 *                      // but somebody might write a value other than 7
 * bne $val,$cmp, top   // if ptr == 7, we exit loop, otherwise retry
 *
 * out:
 *
 * So here are some scenarios:
 *
 * 1. Suppose that the value at *ptr is already 7.
 *
 * The lr.w instruction loads the value 7, and places a reservation
 * on address ptr. The first beq branches immediately to label "out".
 *
 * 2. Suppose that the value at *ptr starts out as 6, then after 100 cycles, a 7 is written.
 *
 * The lr.w instruction loads a 6, and sets a reservation on address "ptr".
 * The first beq will not branch, because a 6 is loaded.
 * The LR.w.aq instruction will stall (in decode is fine) for ~ 100 cycles.
 * The external core writes a 7 to *ptr.
 * The reservation on ptr is cleared.
 * The LR.w.q instruction resumes, loading the 7 from * ptr.
 * The bne exits.
 *
 * 3. Support that the value at *ptr starts out as 6, then after 100 cycles, a 5 is written,
 * then after another 100 cycles a 7 is written to ptr.
 *
 * The lr.w instruction loads a 6, and sets a reservation on address ptr.
 * The first beq will not branch, because a 6 is loaded.
 * The LR.w.aq instruction will stall (in decode is fine) for ~ 100 cycles.
 * The external core writes a 5 to *ptr.
 * The reservation on ptr is cleared.
 * The LR.w.q instruction resumes, loading the 5 from * ptr.
 * The bne jumps to the top of the loop.
 * The lr.w instruction loads a 5, and sets a reservation on address ptr.
 * The first beq will not branch, because a 5 is loaded.
 * The LR.w.aq instruction will stall (in decode is fine) for ~ 100 cycles.
 * The external core writes a 7 to *ptr.
 * The reservation on ptr is cleared.
 * The LR.w.q instruction resumes, loading the 7 from * ptr.
 * The bne exits the loop.
*****************************************************************************/
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define INIT_V      1
#define FIRST_V     5
#define SECOND_V    7

int res_value=0;


//the process will wait until the specified memory address was written with specific value
int spin_cond(int * ptr,  int cond ) {
    int tmp; 
    while(1){
        tmp = bsg_lr( ptr );
        if( tmp == cond ) return 0;  //the data is ready, TODO:shall we clear the reservation?
        else{
            tmp = bsg_lr_aq( ptr );  //stall until somebody clear the reservation

            //Used for debug, print the recieved value
            bsg_remote_ptr_io_store(IO_X_INDEX, &tmp, tmp);

            if( tmp == cond ) return 0; //return if data is expected, otherwise retry
        }
    }
}
#pragma GCC push_options
#pragma GCC optimize ("O0")
//A delay function 
int spin_uncond(int cycles){
    int counter;

    counter = 0;
    while(counter <cycles) counter ++; 
    return counter;
}
#pragma GCC pop_options

//code runs on processor 0
void proc0(void){
    // load the reserved data that is ready
    spin_cond( &res_value, INIT_V);

   // load the reserved data that is ready
    spin_cond( &res_value, SECOND_V);
    
    bsg_finish();
}

//code runs on processor 1
void proc1(void){
    // delay and send the FIRST_V
    spin_uncond( 100 );
    bsg_remote_store(0,0, &res_value, FIRST_V);

   //  delay and send the SECOND_V
    spin_uncond( 100 );
    bsg_remote_store(0,0, &res_value, SECOND_V);
}


////////////////////////////////////////////////////////////////////
int main()
{
  res_value=INIT_V;

  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);


  if (id == 0)          proc0(); 
  else if( id == 1 )    proc1();
  else                  bsg_wait_while(1);
    
  bsg_wait_while(1);
}

