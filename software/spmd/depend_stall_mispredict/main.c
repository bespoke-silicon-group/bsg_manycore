/**
 *  main.c
 *
 *  depend_stall_mispredict
 *
 *  this program tests the correct behavior of dependency stall (by scoreboard),
 *  in the presence of branch mispredict.
 *
 *  When there is branch mispredict in EXE stage, and there is an instruction
 *  in ID stage that has dependency on a pending remote load,
 *  instructions in ID and IF should be flushed immediately,
 *  and the PC should be redirected to the correct branch target.
 *
 *  the fix is to nullify depend_stall, if there is branch_mispredict.
 *
 *
 *  in the inline assembly code, there is a loop, which has an instruction (add)
 *  with data dependency on the next remote load instruction (lw),
 *  and counter incrementer (addi), and branch-less-than (blt) if the counter
 *  is less than some fixed value.
 *
 *  In hobbit, backward branch function is always predicted taken, 
 *  and the predicted branch target (add), stalls on the remote load sent previously.
 */


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int main()
{
  bsg_set_tile_x_y();

  if (__bsg_x == 0 && __bsg_y == 0)
  {

    int i;

    // t1: counter limit
    // t2: remote address
    // t3: remote load register
    asm volatile (" \
      initial:    \
        li %[counter], 0; \
        li t1, 8; \
        li t2, 0x80008000;  \
        sw x0, 0(t2); \
      loop: \
        add x0, t3, t3; \
        lw t3, 0(t2); \
        addi %[counter], %[counter], 1;     \
        blt %[counter], t1, loop;   \
      "             
      : [counter] "+r" (i)
    ); 

    if (i == 8)
    {
      bsg_printf("[PASS] i: %d\n", i);
      bsg_finish();
    }
    else
    {
      bsg_printf("[FAIL] i: %d\n", i);
      bsg_fail();
    }
  }

  bsg_wait_while(1);
}

