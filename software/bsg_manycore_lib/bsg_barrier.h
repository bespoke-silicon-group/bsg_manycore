//====================================================================
// bsg_barrier.h
// 03/08/2018, shawnless.xie@gmail.com
//====================================================================
// The barrier implementation in manycore
//

#ifndef  BSG_BARRIER_H_
#define  BSG_BARRIER_H_

//we need the global bsg_x,bsg_y value.
#include "bsg_set_tile_x_y.h"
#include "bsg_mutex.h"
#include "bsg_manycore.h"

typedef struct bsg_barrier_ {
    bsg_mutex       _mutex          ;

    //the expected count of thread to join
    unsigned int    _joined_count   ;

    //the x_cord and y_cord range of the tiles need to join
    unsigned int    _x_cord_start:8 ;
    unsigned int    _x_cord_end  :8 ;

    unsigned int    _y_cord_start:8 ;
    unsigned int    _y_cord_end  :8 ;

    //the local varialbe that local thread will wait for.
    unsigned int    _local_alert    ;
} bsg_barrier ;

//initial value of the bsg_barrier
#define BSG_BARRIER_INIT( x_cord_start, x_cord_end, y_cord_start, y_cord_end)\
    {   bsg_mutex_unlocked      \
       ,0                       \
       ,x_cord_start            \
       ,x_cord_end              \
       ,y_cord_start            \
       ,y_cord_end              \
       ,0                       \
    }

void bsg_barrier_wait(  bsg_barrier *  p_remote_barrier, int barrier_x_cord, int barrier_y_cord );

//------------------------------------------------------------------

void bsg_barrier_wait(  bsg_barrier *  p_remote_barrier, int barrier_x_cord, int barrier_y_cord ){

    bsg_atomic_add ( &(p_remote_barrier->_mutex), &(p_remote_barrier->_joined_count) );

    //wait all the thread reach the barrier
    if( (bsg_x == barrier_x_cord)  && (bsg_y == barrier_y_cord) ){
        unsigned int  num_threads = ( p_remote_barrier->_x_cord_end - p_remote_barrier->_x_cord_start + 1 )
                                  * ( p_remote_barrier->_y_cord_end - p_remote_barrier->_y_cord_start + 1 );

        unsigned int *p_local_count   = (unsigned int *)( bsg_local_ptr( & (p_remote_barrier->_joined_count)) );

        bsg_wait_local_int( p_local_count, num_threads );

        bsg_mutex_lock ( & (p_remote_barrier->_mutex) );  //<----------------

        for( unsigned int i= p_remote_barrier->_x_cord_start; i <= p_remote_barrier->_x_cord_end; i++ ) {
            for( unsigned int j= p_remote_barrier->_y_cord_start; j<= p_remote_barrier->_y_cord_end; j++) {
                 bsg_remote_store( i, j, &(p_remote_barrier->_local_alert), 0x0 );
            }
        }
        //reset the number of the joined threads
        bsg_remote_store( barrier_x_cord, barrier_y_cord, &(p_remote_barrier->_joined_count), 0x0);

        bsg_mutex_unlock( &(p_remote_barrier->_mutex) ); //----------------->

    } else {
        //wait the 'chief' tile to send signal
        unsigned int *p_local_alert   = (unsigned int *)( bsg_local_ptr( & (p_remote_barrier->_local_alert)) );
        bsg_lr(     p_local_alert )       ;
        bsg_lr_aq(  p_local_alert )       ;
    }
}
#endif
