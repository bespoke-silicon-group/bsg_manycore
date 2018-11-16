
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_token_queue.h"

// this tests that the fence instruction is functional
// we expected to see three packets arrive at the furthest
// away X coordinate before a packet arrives at port 0. 
// This behavior is enforced by the fence instruction.
//

int body(volatile int *far, volatile int *close, int val)
{
    *far = val;
    *far = val;
    *far = val;
    bsg_fence();
    *close = val;
    bsg_fence();
    bsg_finish();
}

int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);
  bsg_remote_int_ptr io_ptr = bsg_remote_ptr_io(IO_X_INDEX,0xCAB0);
  bsg_remote_int_ptr io_ptr2 = bsg_remote_ptr_io(IO_X_INDEX,0xCAB4);
  int val = 23;
  if (id == 0)
  {
    body(io_ptr,io_ptr2,val);
  }
  else
    bsg_wait_while(1);

}

