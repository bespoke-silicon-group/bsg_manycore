#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_mutex.h"
#include "bsg_barrier.h"
//---------------------------------------------------------

#define N 10
// MBT: This test performs N barriers in a row.
//      It demonstrates that bsg_barrier_wait, while never very efficient
//      is horribly inefficient for large numbers of tiles. This is because the internal
//      implementation of bsg barrier essentially uses spinlocks
//      which do not scale.

#define BARRIER_X_END (bsg_tiles_X - 1)
#define BARRIER_Y_END (bsg_tiles_Y - 1)
#define BARRIER_TILES ( (BARRIER_X_END +1) * ( BARRIER_Y_END+1) )

bsg_barrier     tile0_barrier = BSG_BARRIER_INIT(0, BARRIER_X_END, 0, BARRIER_Y_END);

#define array_size(a)               \
    (sizeof(a)/(sizeof((a)[0])))

volatile int data[bsg_tiles_X][bsg_tiles_Y] __attribute__((section (".dram")));

////////////////////////////////////////////////////////////////////
int main() {
        int i, j, id;

        bsg_set_tile_x_y();

        id = bsg_x_y_to_id(bsg_x, bsg_y);

	for (int i = 0; i < N; i++)
	  {
	    if (bsg_x+bsg_y == 0)
	      bsg_print_time();
	    bsg_barrier_wait( &tile0_barrier, 0, 0);
	  }

	if (id == 0)
	  bsg_finish();
	else
	  bsg_wait_while(1);
}

