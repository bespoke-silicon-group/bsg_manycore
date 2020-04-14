//====================================================================
// bsg_tile_group_barrier.h
// 02/14/2019, shawnless.xie@gmail.com
// 02/19/2020, behsani@cs.washington.edu
//====================================================================
// The barrier implementation for tile group in manycore
// Usage:
//      1. #include "bsg_tile_group_barrier_template.hpp"
//      1. bsg_barrier<Y dimension, X dimension> my_barrier;
//      3. my_barrier.sync(); 
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

#ifndef  BSG_TILE_GROUP_BARRIER_TEMPLATE_HPP_
#define  BSG_TILE_GROUP_BARRIER_TEMPLATE_HPP_

// We need the global bsg_x,bsg_y value.
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore.h"
#include "bsg_manycore.hpp"





//------------------------------------------------------------------
//  Helper funcitons.
// check if the char array are all non-zeros
//------------------------------------------------------------------
void inline poll_range( int range, volatile const unsigned int *p){
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
    static constexpr unsigned char    _x_cord_start = 0;
    static constexpr unsigned char    _x_cord_end = BARRIER_X_DIM - 1;
    volatile unsigned int     _local_alert = 0;
    volatile unsigned int     _done_list[ BARRIER_X_DIM ] = {0};


    bsg_row_barrier (){};


    // Reinitializes the done_list to zero
    void reset() {
        for (int i = 0; i < BARRIER_X_DIM; i ++) {
            unsigned int* done_list_ptr = const_cast<unsigned int*> (&_done_list[i]);
            *done_list_ptr = 0;
        }
        return;
    };


    // send the sync singal to the center tile of the row
    // executed by all tiles in the group.
    void sync (unsigned char center_x_cord) {
        //write to the corresponding done
        volatile unsigned int *done_list_ptr = const_cast<unsigned int*> (reinterpret_cast<volatile unsigned int*> (bsg_remote_pointer(center_x_cord, bsg_y, &_done_list[bsg_x - _x_cord_start])));
        *done_list_ptr = 1;
        return;
    };


    // send alert to all of the tiles in the row 
    void alert (){
        for( int i = this->_x_cord_start; i <= this->_x_cord_end; i ++) {
               volatile unsigned int *alert_ptr = const_cast<unsigned int*> (reinterpret_cast<volatile unsigned int*> (bsg_remote_pointer(i, bsg_y, &_local_alert)));
               *alert_ptr = 1;
        }
        return;
    };


    // Poll the entire row barrier done_list until
    // all tiles in row have sent their sync signal
    // Executed by center tile in the row
    void wait_on_sync() {
        int range = this->_x_cord_end - this->_x_cord_start;
        poll_range( range, this->_done_list);
        return;
    };


    // wait on local alert to be set to the given value
    void wait_on_alert (){
        // wait until _local_alert flag is set to 1
        bsg_wait_local_int( (int *) &(this->_local_alert), 1);
        //re-initilized the flag to 0
        unsigned int* alert_ptr = const_cast<unsigned int*> (&_local_alert);
        *alert_ptr = 0;
        return;
    };
};


template <int BARRIER_Y_DIM>
class bsg_col_barrier {
public:
    static constexpr unsigned char    _y_cord_start = 0;
    static constexpr unsigned char    _y_cord_end = BARRIER_Y_DIM - 1;
    volatile unsigned int      _local_alert = 0;
    volatile unsigned int      _done_list[ BARRIER_Y_DIM ] = {0};


    bsg_col_barrier (){};


    // Reinitializes the done_list to zero
    void reset() {
        for (int i = 0; i < BARRIER_Y_DIM; i ++) {
            unsigned int* done_list_ptr = const_cast<unsigned int*> (&_done_list[i]);
            *done_list_ptr = 0;
        }
        return;
    };

    // send the sync singal to the center tile of the column
    // executed by all tiles in the center row
    void sync(unsigned char center_x_cord, unsigned char center_y_cord ){
        //write to the corresponding done
        volatile unsigned int *done_list_ptr = const_cast<unsigned int*> (reinterpret_cast<volatile unsigned int*> (bsg_remote_pointer(center_x_cord, center_y_cord, &_done_list[bsg_y - _y_cord_start])));
        *done_list_ptr = 1;

        #ifdef BSG_BARRIER_DEBUG
               //addr 0x0: row sync'ed
               bsg_remote_ptr_io_store( IO_X_INDEX, 0x0, bsg_y);
        #endif
        return;
    };


    // send alert to all of the tiles in the column 
    void alert (){
        for( int i = this->_y_cord_start; i <= this->_y_cord_end; i ++) {
               volatile unsigned int *alert_ptr = const_cast<unsigned int*> (reinterpret_cast<volatile unsigned int*> (bsg_remote_pointer(bsg_x, i, &_local_alert)));
               *alert_ptr = 1;
        }
        return;
    };


    // Poll the entire col barrier done_list until
    // all tiles in row have sent their sync signal
    // Executed by center tile in column
    void wait_on_sync() {
        int range = this->_y_cord_end - this->_y_cord_start;
        poll_range( range, this->_done_list);
        return;
    };


    // wait on local alert to be set to the given value
    void wait_on_alert (){
        // wait until _local_alert flag is set to 1
        bsg_wait_local_int( (int *) &(this->_local_alert), 1);
        //re-initilized the flag to 0
        unsigned int* alert_ptr = const_cast<unsigned int*> (&_local_alert);
        *alert_ptr = 0;
        return;
    };
};
 




template <int BARRIER_X_DIM, int BARRIER_Y_DIM>
class bsg_barrier {
public:
    bsg_row_barrier<BARRIER_X_DIM> r_barrier;
    bsg_col_barrier<BARRIER_Y_DIM> c_barrier;


    bsg_barrier () {}

    // Initializer with custom x/y start and end coordinates
    bsg_barrier ( unsigned char x_cord_start, unsigned char x_cord_end,
                  unsigned char y_cord_start, unsigned char y_cord_end) {
        r_barrier.init (x_cord_start, x_cord_end);
        c_barrier.init (y_cord_start, y_cord_end);
        return;
    };


    //  The main sync funciton
    void sync() {
        // If barrier dimensions is 1x1, i.e. only a single tile is 
        // participating, there is nothing to be done
        if (BARRIER_Y_DIM == 1 && BARRIER_X_DIM == 1)
                return;

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
                this->c_barrier.reset();
                this->c_barrier.alert();
        }

        // Wait on alert signals from center tile of the center column to be received
        // Send alert signals from center tile of the row to all tiles in the row
        // Reset the local done list of the bsg_row_barrier class
        // Performed by all tiles in the center column 
        if( bsg_x == center_x_cord) {
                this->c_barrier.wait_on_alert();
                this->r_barrier.reset();
                this->r_barrier.alert();
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
        return;
    };
};


#endif // BSG_TILE_GROUP_BARRIER_TEMPLATE_HPP_

