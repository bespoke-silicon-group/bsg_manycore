//====================================================================
// bsg_tile_group_barrier.hpp
// 02/14/2019, shawnless.xie@gmail.com
// 02/19/2020, behsani@cs.washington.edu
//====================================================================
// The barrier implementation for tile group in manycore
// Usage:
//      1. #include "bsg_tile_group_barrier.hpp"
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

#ifndef  BSG_TILE_GROUP_BARRIER_HPP_
#define  BSG_TILE_GROUP_BARRIER_HPP_

// We need the global bsg_x,bsg_y value.
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore.h"
#include "bsg_mutex.hpp"
#include "bsg_manycore.hpp"




template <int BARRIER_X_DIM>
class bsg_row_barrier {
private:

    volatile unsigned int  _local_alert = 0;
    volatile unsigned char _done_list[ BARRIER_X_DIM ] = {0};

public:

    bsg_row_barrier (){
        this->reset();
    };


    // Reinitializes the done_list to zero
    void reset() {
        for (int i = 0; i < BARRIER_X_DIM; i ++) {
            this->_done_list[i] = 0;
        }
        _local_alert = 0;
        return;
    };


    // send the sync signal to the center tile of the row
    // executed by all tiles in the group.
    void sync (unsigned char center_x_cord) {
        //write to the corresponding done
        volatile unsigned char *done_list_ptr = 
            reinterpret_cast<volatile unsigned char*>(
                bsg_tile_group_remote_pointer(center_x_cord,
                                              bsg_y,
                                              &(this->_done_list[bsg_x]))
                );

        *done_list_ptr = 1;
        return;
    };


    // send alert to all of the tiles in the row 
    void alert (){
        for( int x = 0; x < BARRIER_X_DIM; x ++) {
            //write to the corresponding local_alert 
            volatile unsigned int *alert_ptr = 
                reinterpret_cast<volatile unsigned int*>(
                     bsg_tile_group_remote_pointer(x,
                                                   bsg_y,
                                                   &(this->_local_alert))
                     );

            *alert_ptr = 1;
        }
        return;
    };


    // Poll the entire row barrier done_list until
    // all tiles in row have sent their sync signal
    // Executed by center tile in the row
    void wait_on_sync() {
        poll_range(this->_done_list, BARRIER_X_DIM);
        return;
    };


    // wait on local alert to be set to the given value
    void wait_on_alert (){
        // wait until _local_alert flag is set to 1
        bsg_wait_local(reinterpret_cast<int *> (
                           const_cast<unsigned int*> (
                               &(this->_local_alert)
                           )
                      ), 1);

        //re-initilized the flag to 0
        this->_local_alert = 0;
       return;
    };


    friend inline void poll_range(volatile const unsigned char *p, int range);
};


template <int BARRIER_Y_DIM>
class bsg_col_barrier {
private:

    volatile unsigned int  _local_alert = 0;
    volatile unsigned char _done_list[ BARRIER_Y_DIM ] = {0};

public:

    bsg_col_barrier (){
        this->reset();
    };


    // Reinitializes the done_list to zero
    void reset() {
        for (int i = 0; i < BARRIER_Y_DIM; i ++) {
            this->_done_list[i] = 0;
        }
        _local_alert = 0;
        return;
    };

    // send the sync signal to the center tile of the column
    // executed by all tiles in the center row
    void sync(unsigned char center_x_cord, unsigned char center_y_cord ){
        //write to the corresponding done
        volatile unsigned char *done_list_ptr = 
            reinterpret_cast<volatile unsigned char*>(
                bsg_tile_group_remote_pointer(center_x_cord,
                                              center_y_cord,
                                              &(this->_done_list[bsg_y]))
                );

        *done_list_ptr = 1;

        #ifdef BSG_BARRIER_DEBUG
           //addr 0x0: row sync'ed
           bsg_remote_ptr_io_store( IO_X_INDEX, 0x0, bsg_y);
        #endif
        return;
    };


    // send alert to all of the tiles in the column 
    void alert (){
        for( int y = 0; y < BARRIER_Y_DIM; y ++) {
            //write to the corresponding local_alert 
            volatile unsigned int *alert_ptr = 
                reinterpret_cast<volatile unsigned int*>(
                    bsg_tile_group_remote_pointer(bsg_x,
                                                  y,
                                                  &(this->_local_alert))
                    );

               *alert_ptr = 1;
        }
        return;
    };


    // Poll the entire col barrier done_list until
    // all tiles in row have sent their sync signal
    // Executed by center tile in column
    void wait_on_sync() {
        poll_range(this->_done_list, BARRIER_Y_DIM);
        return;
    };


    // wait on local alert to be set to the given value
    void wait_on_alert (){
        // wait until _local_alert flag is set to 1
        bsg_wait_local(reinterpret_cast<int *> (
                           const_cast<unsigned int*> (
                               &(this->_local_alert)
                           )
                      ), 1);

        //re-initilized the flag to 0
        this->_local_alert = 0;
        return;
    };


    friend inline void poll_range(volatile const unsigned char *p, int range);
};
 




template <int BARRIER_X_DIM, int BARRIER_Y_DIM>
class bsg_barrier {
private:

    bsg_row_barrier<BARRIER_X_DIM> r_barrier;
    bsg_col_barrier<BARRIER_Y_DIM> c_barrier;
    static constexpr unsigned char _center_x_cord = (BARRIER_X_DIM - 1) >> 1;
    static constexpr unsigned char _center_y_cord = (BARRIER_Y_DIM - 1) >> 1;

public:

    // Reset row and column barrier 
    bsg_barrier () {
        this->r_barrier.reset();
        this->c_barrier.reset();
    }

    // Reset row and column barrier objects
    void reset() {
        this->r_barrier.reset();
        this->c_barrier.reset();
    }


    //  The main sync funciton
    void sync() {
        // If barrier dimensions is 1x1, i.e. only a single tile is 
        // participating, there is nothing to be done
        if (BARRIER_Y_DIM == 1 && BARRIER_X_DIM == 1)
                return;


        #ifdef BSG_BARRIER_DEBUG
                if( bsg_x == _center_x_cord && bsg_y == _center_y_cord ){
                        bsg_print_time();
                }
        #endif

        // Send sync signals to the center tile of each row 
        r_barrier.sync(_center_x_cord);

        // Wait on sync signals from all tiles in the row to be received
        // Send sync signals to the center tile of the center col
        // Only performed by tiles in the center column
        if( bsg_x == _center_x_cord) {
                this->r_barrier.wait_on_sync();
                this->c_barrier.sync(_center_x_cord, _center_y_cord);
        }

        // Send alert to all tiles of the col
        // Wait on sync signals from all tiles in the center column to be received
        // Send alert signals from the center tile of the center column to all
        // tiles in the cetner column
        // Reset the local done list of the bsg_col_barrier class
        // Only performed by the center tile of the center column
        if( bsg_x == _center_x_cord && bsg_y == _center_y_cord) { 
                this->c_barrier.wait_on_sync();
                this->c_barrier.reset();
                this->c_barrier.alert();
        }

        // Wait on alert signals from center tile of the center column to be received
        // Send alert signals from center tile of the row to all tiles in the row
        // Reset the local done list of the bsg_row_barrier class
        // Performed by all tiles in the center column 
        if( bsg_x == _center_x_cord) {
                this->c_barrier.wait_on_alert();
                this->r_barrier.reset();
                this->r_barrier.alert();
        }

        // Wait on alert signal from the center tile in each row 
        // Once the alert signal is received, all tiles are syncrhonized
        // and can carry on
        this->r_barrier.wait_on_alert();

        #ifdef BSG_BARRIER_DEBUG
                if( bsg_x == _center_x_cord && bsg_y == _center_y_cord ){
                        bsg_print_time();
                }
        #endif
        return;
    };
};


#endif // BSG_TILE_GROUP_BARRIER_HPP_

