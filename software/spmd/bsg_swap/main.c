#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_mutex.h"
// This test will output the number of tiles in the design.
//---------------------------------------------------------

bsg_mutex      tile0_mutex = bsg_mutex_unlocked;
int volatile   count       = 0;

////////////////////////////////////////////////////////////////////
int main() {
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);

  bsg_mutex_ptr         p_mutex = ( bsg_mutex_ptr  ) bsg_remote_ptr( 0, 0, (int *) (& tile0_mutex) );
  bsg_remote_int_ptr    p_value =  bsg_remote_ptr( 0, 0, &count );

  bsg_atomic_add ( p_mutex, p_value );

  if (id == 0) {
    int tmp = 0;

    tmp=bsg_wait_local_int( & count,  bsg_tiles_X * bsg_tiles_Y) ;

    bsg_remote_ptr_io_store(0, 0, tmp);

    bsg_finish();

  }

  bsg_wait_while(1);
}

