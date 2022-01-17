//====================================================================
// bsg_tile_group_barrier.h
// 02/14/2019, shawnless.xie@gmail.com
//====================================================================
// The barrier implementation for tile group in manycore
// Usage:
//      1. #define  BSG_TILE_GROUP_X_DIM           <X dimension>
//      2. #define  BSG_TILE_GROUP_Y_DIM           <Y dimension> 
//      3. #include "bsg_tile_group_barrier.h"
//      4. INIT_TILE_GROUP_BARRIER (<row_barrier_name>, <col_barrier_name>, \
//                               BARRIER_X_START, BARRIER_X_END, BARRIER_Y_START, BARRIER_Y_END);
//      5. bsg_tile_group_barrier( &<row_brrier_name>,  &<col_barrier_name>);
//
//Memory Overhead
//       (2 + X_DIM + 4) + (2 + Y_DIM +4) 
//      =(12 + X_DIM + Y_DIM) BYTES
//
//Worst Case Performance:
//      1. row sync     :   X_DIM     cycles //all tiles writes to center tile of the row
//      2. row polling  : 3*X_DIM     cycles // lbu <xx>; beqz <xxx;
//      3. col sync     :   Y_DIM     cycles //all tiles writes to the center tiles of the col
//      4. col polling  : 3*Y_DIM     cycles // lbu <xx>; beqz <xx>;
//      5. col alert        Y_DIM     cycles // store
//      6. row alert        X_DIM     cycles // store
//      -----------------------------------------------
//                        5*( X_DIM + Y_DIM)
//      For 3x3 group,  cycles = 181, heavy looping/checking overhead for small groups.
#ifndef  BSG_TILE_GROUP_BARRIER_H_
#define  BSG_TILE_GROUP_BARRIER_H_

#ifndef  BSG_TILE_GROUP_X_DIM
#error   Please define BSG_TILE_GROUP_X_DIM before including bsg_tile_group_barrier.h
#endif

#ifndef  BSG_TILE_GROUP_Y_DIM
#error   Please define BSG_TILE_GROUP_Y_DIM before including bsg_tile_group_barrier.h
#endif

//we need the global bsg_x,bsg_y value.
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore.h"

typedef struct _bsg_row_barrier_ {                      
    unsigned char    _x_cord_start;                     
    unsigned char    _x_cord_end  ;                     
    unsigned char    _done_list[ BSG_TILE_GROUP_X_DIM ];
    unsigned int     _local_alert ;                     
} bsg_row_barrier;                                      
                                                        
typedef struct _bsg_col_barrier_ {                       
    unsigned char    _y_cord_start;                     
    unsigned char    _y_cord_end  ;                     
    unsigned char    _done_list[ BSG_TILE_GROUP_Y_DIM]; 
    unsigned int     _local_alert ;                     
} bsg_col_barrier;                                      
                                                        

//initial value of the bsg_barrier
#define INIT_TILE_GROUP_BARRIER( ROW_BARRIER_NAME, COL_BARRIER_NAME, x_cord_start, x_cord_end, y_cord_start, y_cord_end)\
bsg_row_barrier ROW_BARRIER_NAME= {         \
                                (x_cord_start)            \
                               ,(x_cord_end)              \
                               ,{0}                     \
                               ,0                       \
                                };                          \
bsg_col_barrier COL_BARRIER_NAME= {        \
                         (y_cord_start)            \
                        ,(y_cord_end)              \
                        ,{0}                     \
                        ,0                       \
                        };

//------------------------------------------------------------------
//a. check if the char array are all non-zeros
static inline void poll_range( int range, unsigned char *p);
//------------------------------------------------------------------
//b. send alert to all of the tiles in the row 
static inline void alert_row ( bsg_row_barrier * p_row_b);
//------------------------------------------------------------------
//c. send alert to all of the tiles in the col 
static inline void alert_col ( bsg_col_barrier * p_col_b);

//------------------------------------------------------------------
//d. wait a address to be writen by others with specific value 

static inline int bsg_wait_local_int(int * ptr,  int cond );
static inline int bsg_wait_local_int_asm(int * ptr,  int cond );

//------------------------------------------------------------------
// 1. send the sync signal to the center tile of the row
//    executed by all tiles in the group.
static inline void bsg_row_barrier_sync(bsg_row_barrier * p_row_b, int center_x_cord ){
        int  i;
        bsg_row_barrier * p_remote_barrier = (bsg_row_barrier *) bsg_remote_ptr( center_x_cord,    \
                                                                                 bsg_y        ,    \
                                                                                 p_row_b);
        //write to the corresponding done
        p_remote_barrier->_done_list[ bsg_x - p_row_b-> _x_cord_start] = 1; 
}
//------------------------------------------------------------------
//2. wait row sync'ed and send sync signal to center tile of the column
//   executed only by the tiles at the center of the row 
static inline void bsg_col_barrier_sync(bsg_row_barrier * p_row_b, bsg_col_barrier * p_col_b, int center_x_cord, int center_y_cord ){
        int i;
        bsg_col_barrier * p_remote_barrier = (bsg_col_barrier *) bsg_remote_ptr( center_x_cord,    \
                                                                                 center_y_cord,    \
                                                                                 p_col_b);
        int x_range = p_row_b-> _x_cord_end - p_row_b->_x_cord_start;
        poll_range( x_range, p_row_b->_done_list);
        //write to the corresponding done
        p_remote_barrier->_done_list[ bsg_y - p_col_b-> _y_cord_start] = 1; 
        #ifdef BSG_BARRIER_DEBUG
               //addr 0x0: row sync'ed
               bsg_remote_ptr_io_store( IO_X_INDEX, 0x0, bsg_y);
        #endif
}

//------------------------------------------------------------------
//3. wait column sync'ed and send alert signal back to tiles in the column
//   execute only by the center tile of the group
static inline void bsg_col_barrier_alert(  bsg_col_barrier *  p_col_b ) {
        //the center tile needs to check the status
        int i;
        int y_range = p_col_b-> _y_cord_end - p_col_b->_y_cord_start;
        poll_range(y_range, p_col_b->_done_list);
        #ifdef BSG_BARRIER_DEBUG
               //addr 0x4: column sync'ed
               bsg_remote_ptr_io_store( IO_X_INDEX, 0x4, bsg_y);
        #endif
        //re-initilized the local column sync array.
        for( i= 0; i <= y_range; i++) {
              p_col_b->_done_list[ i ] = 0;
        }
        //write alert signal to all tiles in the column
        alert_col( p_col_b );

}

//------------------------------------------------------------------
//4. wait column alert signal and send alert signal back to all tiles of the row
//   executed only by the tiles at the center of the row
static inline void bsg_row_barrier_alert(  bsg_row_barrier *  p_row_b, bsg_col_barrier * p_col_b ){
        int i;
        int x_range = p_row_b-> _x_cord_end - p_row_b->_x_cord_start;
        
        bsg_wait_local_int( (int *) &(p_col_b -> _local_alert),  1);

        #ifdef BSG_BARRIER_DEBUG
               //addr 0x8: column alerted. Starting to alter tiles in the row
               bsg_remote_ptr_io_store( IO_X_INDEX, 0x8, bsg_y);
        #endif
        //re-initilized the local row sync array.
        for( i= 0; i <= x_range; i++) {
              p_row_b->_done_list[ i ] = 0;
        }
        //clear the column alert signal
        p_col_b -> _local_alert = 0;
        //write alert signal to all tiles in the row
        alert_row( p_row_b);
}
//------------------------------------------------------------------
//5. wait the row alert signal 
//   execute by all tiles in the group
//------------------------------------------------------------------
static inline void bsg_tile_wait(bsg_row_barrier * p_row_b){
        bsg_wait_local_int( (int *) &(p_row_b->_local_alert), 1);
        //re-initilized the flag.
        p_row_b->_local_alert = 0;
}

//------------------------------------------------------------------
//  The main sync funciton
//------------------------------------------------------------------
static inline void bsg_tile_group_barrier(bsg_row_barrier *p_row_b, bsg_col_barrier * p_col_b){
        int center_x_cord = (p_row_b->_x_cord_start + p_row_b->_x_cord_end)/2;

        int center_y_cord = (p_col_b->_y_cord_start + p_col_b->_y_cord_end)/2;

        #ifdef BSG_BARRIER_DEBUG
                if( bsg_x == center_x_cord && bsg_y == center_y_cord ){
                        bsg_print_time();
                }
        #endif
        //1. send sync signals to center of the row 
        bsg_row_barrier_sync(p_row_b, center_x_cord );

        //2. send sync signals to the center of the col
        if( bsg_x == center_x_cord) 
                bsg_col_barrier_sync( p_row_b, p_col_b, center_x_cord, center_y_cord );
        //3. send alert to all tiles of the col
        if( bsg_x == center_x_cord && bsg_y == center_y_cord) 
                bsg_col_barrier_alert( p_col_b);
        //4. send alert to all tiles of the row
        if( bsg_x == center_x_cord)
                bsg_row_barrier_alert(p_row_b, p_col_b);
        //5. wait the row alert signal
        bsg_tile_wait( p_row_b );
        #ifdef BSG_BARRIER_DEBUG
                if( bsg_x == center_x_cord && bsg_y == center_y_cord ){
                        bsg_print_time();
                }
        #endif
}
//------------------------------------------------------------------
//  Helper funcitons.
//------------------------------------------------------------------
static inline void poll_range( int range, unsigned char *p){
        int i;
        do{
                for( i= 0; i <= range; i++) {
                        if ( p[ i ] == 0) break;
                }
        }while ( i <= range);
}

static inline void alert_col( bsg_col_barrier * p_col_b){
        int i;
        bsg_col_barrier * p_remote_barrier;
        for( i= p_col_b-> _y_cord_start; i <= p_col_b-> _y_cord_end; i++) {
               p_remote_barrier = (bsg_col_barrier *) bsg_remote_ptr( bsg_x,    \
                                                                      i,        \
                                                                      p_col_b);
               p_remote_barrier->_local_alert = 1;
        }
}

static inline void alert_row( bsg_row_barrier * p_row_b){
        int i;
        bsg_row_barrier * p_remote_barrier;
        for( i= p_row_b-> _x_cord_start; i <= p_row_b-> _x_cord_end; i++) {
               p_remote_barrier = (bsg_row_barrier *) bsg_remote_ptr( i,        \
                                                                      bsg_y,    \
                                                                      p_row_b);
               p_remote_barrier->_local_alert = 1;
        }
}

// wait until the specified memory address was written with specific value
static inline int bsg_wait_local_int(int * ptr,  int cond ) {
    int tmp;
    while(1){
        tmp = bsg_lr( ptr );
        if( tmp == cond ) return tmp;  //the data is ready
        else{
            tmp = bsg_lr_aq( ptr );    //stall until somebody clear the reservation
            if( tmp == cond ) return tmp; //return if data is expected, otherwise retry
        }
    }
}

// assembly equivalent of the above; note stalls after lr's, and at least one branch
// mispredict on exit path

static inline int bsg_wait_local_int_asm (int *ptr, int cond)
{ int tmp; __asm__ __volatile__("2: lr.w %0, %1\n\t"
                                "beq %0, %2, 1f\n\t"
                                "lr.w.aq %0, %1\n\t"
                                "bne %0, %2, 2b\n\t"
                                "1:\n\t" : "=&r" (tmp) : "A" (*ptr), "r" (cond)); 
  return tmp; 
}

// checks to see if a word is set; waits if it is not
// but assumes that any incoming word is the correct word

static inline int bsg_wait_local_int_asm_blind (int *ptr, int cond)
{ int tmp; __asm__ __volatile__("lr.w %0, %1\n\t"
                                "beq %0, %2, 1f\n\t"
                                "lr.w.aq %0, %1\n\t"
                                "1:\n\t" : "=&r" (tmp) : "A" (*ptr), "r" (cond)); 
  return tmp; 
}

// this checks to see if 16 consecutive bytes have been set to all 0xFF or 0x00
// and when it has, it writes the same value to ptr_out.
//
// the code is written to minimize load/use stalls and also to minimize branch
// mispredicts on the case when everything has arrived. hence we have the off-path
// branches all jump forward

// this code is polling so should only be used when you know the word is coming in
// quickly; e.g. a barrier

static inline int bsg_join4_relay  (volatile int *ptr_in, int cond, char *ptr_out)
{ int tmp; int tmp2; __asm__ __volatile__(
				"4:\n\t"
				"lw %0, 0+%4\n\t"
                                "lw %1, 4+%4\n\t"
                                "bne %0, %2, 3f\n\t"        
                                "bne %1, %2, 3f\n\t"
				"2: lw %0, 8+%4\n\t"
                                "lw %1, 12+%4\n\t"
                                "bne %0, %2, 1f\n\t"        
                                "bne %1, %2, 1f\n\t"
				"sb %2, %3\n\t"
                                "j 0f \n\t"
				"3:j 4b\n\t"
				"1:j 2b\n\t"
                                "0:\n\t"
					  : "=&r" (tmp), "=&r" (tmp2) : "r" (cond), "A" (*ptr_out), "A" (*ptr_in)); 
  return tmp; 
}

static inline int bsg_join2  (volatile int *ptr_in, int cond)
{ int tmp; int tmp2; __asm__ __volatile__(
				"4:\n\t"
				"lw %0, 0+%3\n\t"
                                "lw %1, 4+%3\n\t"
                                "bne %0, %2, 3f\n\t"        
                                "bne %1, %2, 3f\n\t"
                                "j 0f \n\t"
				"3:j 4b\n\t"
                                "0:\n\t"
					  : "=&r" (tmp), "=&r" (tmp2) : "r" (cond), "A" (*ptr_in)); 
  return tmp; 
}



#endif
