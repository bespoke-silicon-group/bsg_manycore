// testing credit limit CSR


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 32
int data[N] __attribute__ ((section (".dram"))) = {0};
extern int* _interrupt_arr;


int main() {
  int i;
  bsg_set_tile_x_y();

  // read current credit limit
  int curr_limit;
  asm volatile ("csrr %[curr_limit], 0xfc0" : [curr_limit] "=r" (curr_limit));
  if (curr_limit != 32) bsg_fail();
  bsg_printf("current credit limit = %d\n", curr_limit);

  // store data and check
  int* data_ptr = data;
  int curr_data = 1;

  int read_buffer[N];

  // for each round, decrement credit counter by 1
  do {
    // store curr data in burst
    asm volatile ("sw %[curr_data], 0(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 4(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 8(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 12(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 16(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 20(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 24(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 28(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 32(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 36(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 40(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 44(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 48(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 52(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 56(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 60(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 64(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 68(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 72(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 76(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 80(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 84(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 88(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 92(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 96(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 100(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 104(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 108(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 112(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 116(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 120(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 124(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    // read back and validate
    #pragma GCC unroll 8
    for (int i = 0; i < N; i++) {
      read_buffer[i] = data_ptr[i];
    }
    for (int i = 0; i < N; i++) {
      if (read_buffer[i] != curr_data) bsg_fail();
    }
    // decrement credit limit
    curr_limit--;
    // increment curr_data
    curr_data++;
    asm volatile ("csrw 0xfc0, %[curr_limit]" : : [curr_limit] "r" (curr_limit));
    // print time
    bsg_print_time();
  } while (curr_limit != 1);
  

  // for each round, increment credit counter by 1
  do {
    // store curr data in burst
    asm volatile ("sw %[curr_data], 0(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 4(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 8(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 12(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 16(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 20(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 24(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 28(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 32(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 36(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 40(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 44(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 48(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 52(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 56(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 60(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 64(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 68(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 72(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 76(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 80(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 84(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 88(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 92(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 96(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 100(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 104(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 108(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 112(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 116(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 120(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    asm volatile ("sw %[curr_data], 124(%[data_ptr])" : : [curr_data] "r" (curr_data), [data_ptr] "r" (data_ptr)); 
    // read back and validate
    #pragma GCC unroll 8
    for (int i = 0; i < N; i++) {
      read_buffer[i] = data_ptr[i];
    }
    for (int i = 0; i < N; i++) {
      if (read_buffer[i] != curr_data) bsg_fail();
    }
    // decrement credit limit
    curr_limit++;
    // increment curr_data
    curr_data++;
    asm volatile ("csrw 0xfc0, %[curr_limit]" : : [curr_limit] "r" (curr_limit));
    // print time
    bsg_print_time();
  } while (curr_limit != 32);

  
  bsg_finish();
  bsg_wait_while(1);
}

