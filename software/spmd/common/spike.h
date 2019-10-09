#ifndef _SPIKE_H
#define _SPIKE_H_

#include <stdint.h>

extern volatile int64_t tohost;
extern volatile int64_t fromhost;
extern volatile const int spike_run;

#define replace_spike_call(func, ...) \
  if (spike_run == 1) { \
    spike_ ## func (__VA_ARGS__); \
  } else { \
    bsg_ ## func (__VA_ARGS__); \
  }

#define spike_set_tile_x_y()

#define spike_finish() \
  do { \
    volatile int* ptr = &tohost; \
    *ptr = 0x1; \
    while(1); \
  } while(0)

#define spike_fail() \
  do { \
    volatile int* ptr = &tohost; \
    *ptr = 0x3; \
    while(1); \
  } while(0)

#define spike_putchar(ch) \
  do { \
    volatile int* ptr = &tohost; \
    *ptr = (ch << 8) | 0x2; \
    while(fromhost == 0); \
    fromhost = 0; \
  } while(0)

#define spike_print_time()

#define spike_remote_ptr_io_store(x, y, val) \
  printf("store to io: %d\n", val)


#endif // _SPIKE_H_
