/*
 * NB WAW Test
 *
 * This test WAW hazard handling by generating a instruction
 * sequence with two consecutive load to a register followed
 * by a multiply instruction. Different delays between the
 * two loads may trigger WAW violation on different manycore
 * configurations.
 */


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

volatile int load_buf[4] __attribute__((section(".dram"))) = {1, 2, 3, 0};
volatile int store_buf[20];
volatile int* long_remote = bsg_remote_ptr(4, 4, 0x1200);

int main()
{
  bsg_set_tile_x_y();

  if (__bsg_id == 0) {
    // N models the delay between first and second load to a same
    // register. This for loop sweeps across different delays. GCC
    // unroll is important to create exact same instruction sequences
    // with different Ns.
    #pragma GCC unroll 20
    for(int N=1; N<=20; ++N) {
      // Assume these loads happned way before,
      // in the program. Blocking them by putchar to
      // emulate such a scenario.
      int third = load_buf[2];
      int last = load_buf[3];
      *long_remote = 0;
      bsg_putchar('0' + third + last + *long_remote);
      bsg_putchar('\n');

      // The bug arises in a scenario where a remote load to
      // a reg is followed by a remote load to same reg in
      // possibly differen piece of code.
      int res = load_buf[0];
      int prod = 0;

      // This models the delay of transistion to different
      // section of the program.
      #pragma GCC unroll 20
      for(int i=0; i<N; ++i)
        store_buf[i] = 0;

      // Long remote to fill up the buffer causing force write back
      int sec = *long_remote;

      // This `if` models some code in totally different section
      // of the program.
      if(last == 0)
        // Second load to res followed by mul causes a WAW hazard
        res = load_buf[3];
        prod = third * last;

      res += sec + prod;

      if (res != 0)
        bsg_fail();
    }

    bsg_finish();
  }

  bsg_wait_while(1);
}
