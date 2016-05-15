
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

volatile int foo[10];
volatile char *cp =  (char *)  &foo[0];
volatile short *sp = (short *) &foo[0];

int main()
{
  bsg_set_tile_x_y();

  bsg_remote_ptr_io_store(0,0,0);

  foo[0] = 1;                       // set foo[0] to 1
  bsg_wait_while(foo[0]!=1);

  bsg_remote_ptr_io_store(0,0,1);

  cp[0] = 2;
  bsg_wait_while(foo[0]!=2);

  bsg_remote_ptr_io_store(0,0,2);

  cp[1] = 3;
  bsg_wait_while(foo[0]!=0x302);

  bsg_remote_ptr_io_store(0,0,3);

  cp[2] = 4;
  bsg_wait_while(foo[0]!=0x040302);

  bsg_remote_ptr_io_store(0,0,4);

  cp[3] = 5;
  bsg_wait_while(foo[0]!=0x05040302);

  bsg_remote_ptr_io_store(0,0,5);

  sp[1] = 0x9080;
  bsg_wait_while(foo[0]!=0x90800302);

  bsg_remote_ptr_io_store(0,0,6);

  bsg_finish();
}

