#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int big_jump();

int main()
{

  bsg_set_tile_x_y();
  int sum;
  sum = 0;

  if ((__bsg_x == 0) && (__bsg_y == 0)) {
    //big_jump();
    bsg_finish();
  }

  bsg_wait_while(1);
  
}

/* #define JUMP_SIZE "(0x00001000-4)" */
/* #define LABEL_PREFIX "" */

/* int big_jump() */
/* { */
/*   asm volatile ("\n" */
/* 		"" LABEL_PREFIX "0: j " LABEL_PREFIX "1f\n" */
/* 		".space " JUMP_SIZE ", 0\n" */
/* 		"" LABEL_PREFIX "1: j " LABEL_PREFIX "2f\n" */
/* 		".space " JUMP_SIZE ", 0\n" */
/* 		"" LABEL_PREFIX "2:\n"); */
/*   return 0; */
/* } */
