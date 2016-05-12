
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

extern int infinite();

int foo[8] = { -1,-1,-1,-1,-1,-1,-1,-1 };

int main()
{
  bsg_set_tile_x_y();

  if (!bsg_x && !bsg_y)
  {
    // repeatedly send store requests to other tile
    bsg_remote_int_ptr brip = bsg_remote_ptr(1,0,foo);
    while (1)
    {
      brip[0] = 1;
      brip[1] = 2;
      brip[2] = 3;
      brip[3] = 4;
      brip[4] = 5;
      brip[5] = 6;
      brip[6] = 7;
      brip[7] = 8;
    }
  }
  else
  {
    infinite(); // ASM, should be infinite loop, but isn't!

    //  398: 00000e17          auipc tt,0x0 <--- accidentally skipped
    //  39c: 0c7e2423          swt2,200(t3) # 460 <foo>
    //  3a0: fe031ce3          bnez t1,398 <t>
    //  3a4: 00000313          li   t1,0   <--- accidentally executed
    //  3a8: 00008067          ret

    bsg_finish();
  }
}

