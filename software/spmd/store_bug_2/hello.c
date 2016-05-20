
#include "bsg_manycore.h"

int bsg_x = -1;
int bsg_y = -1;

int bsg_set_tile_x_y()
{
  // everybody stores to tile 0,0
  bsg_remote_store(0,0,&bsg_x,0);
  bsg_remote_store(0,0,&bsg_y,0);

  // make sure memory ops above are not moved down
  bsg_compiler_memory_barrier();

  // wait for my tile number to change
  bsg_wait_while((bsg_volatile_access(bsg_x) == -1) || (bsg_volatile_access(bsg_y) == -1));

  // make sure memory ops below are not moved above
  bsg_compiler_memory_barrier();

  // head of each column is responsible for
  // propagating to next column
  if ((bsg_x == 0)
      && ((bsg_y + 1) != bsg_tiles_Y)
    )
  {
    bsg_remote_store(0,bsg_y+1,&bsg_x,bsg_x);
    bsg_remote_store(0,bsg_y+1,&bsg_y,bsg_y+1);
  }

  // propagate across each row
  if ((bsg_x+1) != bsg_tiles_X)
  {
    bsg_remote_store(bsg_x+1,bsg_y,&bsg_x,bsg_x+1);
    bsg_remote_store(bsg_x+1,bsg_y,&bsg_y,bsg_y);
  }
}


volatile int tmp1 = 0;
int tmp2 = 0;

int main()
{
  bsg_set_tile_x_y();

  if (bsg_x == 0 && bsg_y == 0) {
    ++tmp1;
    ++tmp1;
    ++tmp1;
    ++tmp1;
    ++tmp1;
    ++tmp1;
    ++tmp1;
    bsg_remote_store(0, 1, &tmp1, tmp1);
    bsg_finish();
  }   

  ++tmp2;
  bsg_remote_store(0, 0, &tmp2, tmp2);
  bsg_remote_store(0, 0, &tmp2, tmp2);
  bsg_remote_store(0, 0, &tmp2, tmp2);
  bsg_remote_store(0, 0, &tmp2, tmp2);



  while(1);
}

