// Program to print 10 fibonacci numbers; A sample program that will get profiled

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

extern int _histogram_arr;

#ifndef HIST_SPACE
#define HIST_SPACE 16777216
#endif

#define NUM_TILES bsg_group_size

// Sample program to print 10 fibonacci numbers
void fibonacci()
{
  int i;
  int a = 0;
  int b = 1;
  int temp = 0;

  for (i = 0; i < 10; i++)
  {
    temp = a + b;
    a = b;
    b = temp;
  }

  if (a != 55)
    bsg_fail();
}

void read_histogram()
{
  // Fixme: This array is populated statically by observing disassembly. Need to make it standalone
  int expectation[10] = {1 * NUM_TILES, 1 * NUM_TILES, 10 * NUM_TILES, 10 * NUM_TILES, 10 * NUM_TILES, 10 * NUM_TILES, 10 * NUM_TILES, 1 * NUM_TILES, 1 * NUM_TILES, 1 * NUM_TILES};

  int *i;
  int val;
  int count = 0;
  for (i = &_histogram_arr; i < (&_histogram_arr + (HIST_SPACE >> 2)); i++)
  {
    val = *i;
    if (val != 0)
    {
      bsg_printf("%p: %x\n", i, val);
      if (expectation[count] != val)
        bsg_fail();
      count++;
    }    
  }

  bsg_finish();
}

void main()
{
  // tile setup
  bsg_set_tile_x_y();


  // Start profiling code, enable interrupts
  int mie, mstatus;
  mie = 0x20000;
  mstatus = 0x8;
  __asm__ __volatile__ ("csrw mie, %0": : "r" (mie));
  __asm__ __volatile__ ("csrw mstatus, %0" : : "r" (mstatus));

  // Code to be profiled
  fibonacci();

  // Reading histogram, disable interrupts
  mie = mstatus = 0;
  __asm__ __volatile__ ("csrw mie, %0": : "r" (mie));
  __asm__ __volatile__ ("csrw mstatus, %0" : : "r" (mstatus));

  if (__bsg_id == 0)
  {
    // read histogram
    read_histogram();
  }
  
  bsg_wait_while(1);
}
