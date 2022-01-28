//  This test aims to measure the switching activity while the tile is in sleep by lr_aq.
//  The first tile goes to sleep immediately. The second tile triggers the saif gen, and wait 100~ cycles, and dump the saif file.

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int main()
{
    bsg_set_tile_x_y();

    if (__bsg_id == 0) {
      int tmp;
      bsg_lr(&tmp);
      bsg_lr_aq(&tmp);
    } else if (__bsg_id == 1) {
      // first, count to 100 to make sure that the first tile is in sleep.
      volatile int count = 0;
      while (count < 100) {
        count++;
      }
    
      // start saif gen
      bsg_saif_start();
      bsg_fence();
      
      // count again
      count = 0;
      while (count < 200) {
        count++;
      }
      
      // send saif end and fence.
      bsg_saif_end();
      bsg_fence();
      
      bsg_finish();
    }
  

    bsg_wait_while(1);
}

