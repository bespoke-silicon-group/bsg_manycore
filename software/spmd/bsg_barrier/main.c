#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_mutex.h"
#include "bsg_barrier.h"
//---------------------------------------------------------

#define BARRIER_X 0
#define BARRIER_Y 0

#define BARRIER_X_END (bsg_tiles_X - 1)
#define BARRIER_Y_END (bsg_tiles_Y - 1)
#define BARRIER_TILES ( (BARRIER_X_END +1) * ( BARRIER_Y_END+1) )
bsg_barrier     tile0_barrier = BSG_BARRIER_INIT(0, BARRIER_X_END, 0, BARRIER_Y_END);
////////////////////////////////////////////////////////////////////
int main() {
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);

  bsg_barrier *p_barrier  = ( bsg_barrier *  ) bsg_remote_ptr( 0, 0, (int *) (& tile0_barrier) );

  if( id < BARRIER_TILES ){
        for( int i =0; i <= id; i++){
          for(int j=0; j<32; j++){
              asm volatile ("nop;");
          }
          bsg_remote_ptr_io_store(0, 0,  (id<<16) | i);
        }
        //wait all threads finish

        bsg_barrier_wait( p_barrier, 0, 0);
  }

  if( id == 0)  bsg_finish();
  else          bsg_wait_while(1);
}

