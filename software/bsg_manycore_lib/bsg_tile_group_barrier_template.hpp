//====================================================================
// bsg_tile_group_barrier.h
// 02/14/2019, shawnless.xie@gmail.com
// 02/19/2020, behsani@cs.washington.edu
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
#ifndef  BSG_TILE_GROUP_BARRIER_TEMPLATE_H_
#define  BSG_TILE_GROUP_BARRIER_TEMPLATE_H_

// We need the global bsg_x,bsg_y value.
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore.h"






//------------------------------------------------------------------
//  Helper funcitons.
// check if the char array are all non-zeros
//------------------------------------------------------------------
void inline poll_range( int range, unsigned char *p){
        int i;
        do{
                for( i= 0; i <= range; i++) {
                        if ( p[ i ] == 0) break;
                }
        }while ( i <= range);
}

//------------------------------------------------------------------
// Wait until the specified memory address is written by other tiles
// with specific value
//------------------------------------------------------------------
inline int bsg_wait_local_int(int * ptr,  int cond ) {
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




template <int BARRIER_X_DIM>
class bsg_row_barrier {
public:
    unsigned char    _x_cord_start;
    unsigned char    _x_cord_end;
    unsigned char    _done_list[ BARRIER_X_DIM ] = {0};
    unsigned int     _local_alert;

    bsg_row_barrier (){};

    bsg_row_barrier (unsigned char x_cord_start ,unsigned char x_cord_end) {
        _x_cord_start = x_cord_start;
        _x_cord_end = x_cord_end;
        _local_alert = 0;
    }; 

    bsg_row_barrier& init (unsigned char x_cord_start ,unsigned char x_cord_end) {
        _x_cord_start = x_cord_start;
        _x_cord_end = x_cord_end;
        _local_alert = 0;
        return *this;
    }; 


    // Reinitializes the done_list to zero
    bsg_row_barrier& reset() {
        for (int i = 0; i < BARRIER_X_DIM; i ++) {
            this->_done_list[i] = 0;
        }
        return *this;
    };


    // send the sync singal to the center tile of the row
    // executed by all tiles in the group.
    // TODO: set center_x_cord and bsg_y as input arguments
    bsg_row_barrier& sync (unsigned char center_x_cord) {
        bsg_row_barrier<BARRIER_X_DIM> * p_remote_barrier = (bsg_row_barrier<BARRIER_X_DIM> *) bsg_remote_ptr( center_x_cord,    \
                                                                                                               bsg_y        ,    \
                                                                                                               this);
        //write to the corresponding done
        p_remote_barrier->_done_list[ bsg_x - this->_x_cord_start] = 1; 
        return *this;
    };


    // send alert to all of the tiles in the row 
    bsg_row_barrier& alert (){
        bsg_row_barrier<BARRIER_X_DIM> * p_remote_barrier;
        for( int i = this->_x_cord_start; i <= this->_x_cord_end; i ++) {
               p_remote_barrier = (bsg_row_barrier<BARRIER_X_DIM> *) bsg_remote_ptr( i,        \
                                                                                     bsg_y,    \
                                                                                     this);
               p_remote_barrier->_local_alert = 1;
        }
        return *this;
    };


    // Poll the entire row barrier done_list until
    // all tiles in row have sent their sync signal
    // Executed by center tile in the row
    bsg_row_barrier& wait_on_sync() {
        int range = this->_x_cord_end - this->_x_cord_start;
        poll_range( range, this->_done_list);
        return *this;
    };


    // wait on local alert to be set to the given value
    bsg_row_barrier& wait_on_alert (){
        // wait until _local_alert flag is set to 1
        bsg_wait_local_int( (int *) &(this->_local_alert), 1);
        //re-initilized the flag to 0
        this->_local_alert = 0;
        return *this;
    };
};


template <int BARRIER_Y_DIM>
class bsg_col_barrier {
public:
    unsigned char    _y_cord_start;
    unsigned char    _y_cord_end;
    unsigned char    _done_list[ BARRIER_Y_DIM ] = {0};
    unsigned int     _local_alert ;

    bsg_col_barrier (){};

    bsg_col_barrier (unsigned char y_cord_start ,unsigned char y_cord_end) {
        _y_cord_start = y_cord_start;
        _y_cord_end = y_cord_end;
        _local_alert = 0;
    };

    bsg_col_barrier& init (unsigned char y_cord_start ,unsigned char y_cord_end) {
        _y_cord_start = y_cord_start;
        _y_cord_end = y_cord_end;
        _local_alert = 0;
        return *this;
    };


    // Reinitializes the done_list to zero
    bsg_col_barrier& reset() {
        for (int i = 0; i < BARRIER_Y_DIM; i ++) {
            this->_done_list[i] = 0;
        }
        return *this;
    };

    // send the sync singal to the center tile of the column
    // executed by all tiles in the center row
    bsg_col_barrier& sync(unsigned char center_x_cord, unsigned char center_y_cord ){
        bsg_col_barrier<BARRIER_Y_DIM> * p_remote_barrier = (bsg_col_barrier<BARRIER_Y_DIM> *) bsg_remote_ptr( center_x_cord,    \
                                                                                                               center_y_cord,    \
                                                                                                               this);
        //write to the corresponding done
        p_remote_barrier->_done_list[ bsg_y - this->_y_cord_start] = 1; 
        #ifdef BSG_BARRIER_DEBUG
               //addr 0x0: row sync'ed
               bsg_remote_ptr_io_store( IO_X_INDEX, 0x0, bsg_y);
        #endif
        return *this;
    };


    // send alert to all of the tiles in the column 
    bsg_col_barrier& alert (){
        bsg_col_barrier<BARRIER_Y_DIM> * p_remote_barrier;
        for( int i = this->_y_cord_start; i <= this->_y_cord_end; i ++) {
               p_remote_barrier = (bsg_col_barrier<BARRIER_Y_DIM> *) bsg_remote_ptr( bsg_x,    \
                                                                                     i,        \
                                                                                     this);
               p_remote_barrier->_local_alert = 1;
        }
        return *this;
    };


    // Poll the entire col barrier done_list until
    // all tiles in row have sent their sync signal
    // Executed by center tile in column
    bsg_col_barrier& wait_on_sync() {
        int range = this->_y_cord_end - this->_y_cord_start;
        poll_range( range, this->_done_list);
        return *this;
    };


    // wait on local alert to be set to the given value
    bsg_col_barrier& wait_on_alert (){
        // wait until _local_alert flag is set to 1
        bsg_wait_local_int( (int *) &(this->_local_alert), 1);
        //re-initilized the flag to 0
        this->_local_alert = 0;
        return *this;
    };
};
 




template <int BARRIER_Y_DIM, int BARRIER_X_DIM>
class bsg_barrier {
public:
    bsg_row_barrier<BARRIER_X_DIM> r_barrier;
    bsg_col_barrier<BARRIER_Y_DIM> c_barrier;


    // Initializer with default x/y start and end coordinates
    bsg_barrier () {
        r_barrier.init (0, BARRIER_X_DIM -1);
        c_barrier.init (0, BARRIER_Y_DIM -1);
        return;
    };

    // Initializer with custom x/y start and end coordinates
    bsg_barrier ( unsigned char x_cord_start, unsigned char x_cord_end,
                  unsigned char y_cord_start, unsigned char y_cord_end) {
        r_barrier.init (x_cord_start, x_cord_end);
        c_barrier.init (y_cord_start, y_cord_end);
        return;
    };


    //  The main sync funciton
    bsg_barrier& sync() {
        int center_x_cord = (this->r_barrier._x_cord_start + this->r_barrier._x_cord_end) / 2;
        int center_y_cord = (this->c_barrier._y_cord_start + this->c_barrier._y_cord_end) / 2;

        #ifdef BSG_BARRIER_DEBUG
                if( bsg_x == center_x_cord && bsg_y == center_y_cord ){
                        bsg_print_time();
                }
        #endif

        // Send sync signals to the center tile of each row 
        r_barrier.sync(center_x_cord);

        // Wait on sync signals from all tiles in the row to be received
        // Send sync signals to the center tile of the center col
        // Only performed by tiles in the center column
        if( bsg_x == center_x_cord) {
                this->r_barrier.wait_on_sync();
                this->c_barrier.sync(center_x_cord, center_y_cord);
        }

        // Send alert to all tiles of the col
        // Wait on sync signals from all tiles in the center column to be received
        // Send alert signals from the center tile of the center column to all
        // tiles in the cetner column
        // Reset the local done list of the bsg_col_barrier class
        // Only performed by the center tile of the center column
        if( bsg_x == center_x_cord && bsg_y == center_y_cord) { 
                this->c_barrier.wait_on_sync();
                this->c_barrier.alert();
                this->c_barrier.reset();
        }

        // Wait on alert signals from center tile of the center column to be received
        // Send alert signals from center tile of the row to all tiles in the row
        // Reset the local done list of the bsg_row_barrier class
        // Performed by all tiles in the center column 
        if( bsg_x == center_x_cord) {
                this->c_barrier.wait_on_alert();
                this->r_barrier.alert();
                this->r_barrier.reset();
        }

        // Wait on alert signal from the center tile in each row 
        // Once the alert signal is received, all tiles are syncrhonized
        // and can carry on
        this->r_barrier.wait_on_alert();

        #ifdef BSG_BARRIER_DEBUG
                if( bsg_x == center_x_cord && bsg_y == center_y_cord ){
                        bsg_print_time();
                }
        #endif
        return *this;
    };
};


#endif
