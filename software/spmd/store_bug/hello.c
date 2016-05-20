
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

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

