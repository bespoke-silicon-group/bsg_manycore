// MBT 5-15-2016
// supports "viral booting"
// where code spreads across the tiles, rather
// than having the SPMD loader individually load them.
//
// Usage: put go_viral() as the first thing
// in main.
//

#include "bsg_manycore.h"

// these are private variables
// we do not make them volatile
// so that they may be cached

int bsg_x = -1;
int bsg_y = -1;

int bsg_id = 0;
int bsg_current_size = 1;

#define bsg_memory_words 8192

int go_viral() {
  bsg_x = bsg_id_to_x(bsg_id);
  bsg_y = bsg_id_to_y(bsg_id);

  while (1)
  {
    int target_id = bsg_current_size+bsg_id;

    if (target_id >= bsg_num_tiles)
      break;

    int target_x = bsg_id_to_x(target_id);
    int target_y = bsg_id_to_y(target_id);

    bsg_remote_int_ptr ptr 
      = bsg_remote_ptr(target_x, target_y,0);
  
    int *local_mem = (int *) (0);

    // update current size so it gets propagated
    bsg_current_size = (bsg_current_size << 1);

    for (int i = 0; i < bsg_memory_words; i+=4)
    {
      int a = local_mem[i];
      int b = local_mem[i+1];
      int c = local_mem[i+2];
      int d = local_mem[i+3];

      ptr[i+0] = a;
      ptr[i+1] = b;
      ptr[i+2] = c;
      ptr[i+3] = d;
    }

    // update remote node with its ID
    bsg_remote_store(target_x,target_y,&bsg_id,target_id);

    // then, wake up the remote tile!
    bsg_remote_unfreeze(target_x,target_y);
  }
}

int main()
{
  go_viral();

  bsg_print_time();
  if (bsg_id == (bsg_num_tiles-1))
    bsg_finish();
  bsg_wait_while(1);
}
