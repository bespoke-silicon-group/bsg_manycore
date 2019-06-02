#ifndef _SPIKE_H
#define _SPIKE_H_

extern volatile int tohost;
extern volatile int fromhost;

#define __bsg_id 1

#define bsg_finish() \
  do { \
    volatile int* ptr = &tohost; \
    *ptr = 0x1; \
    while(1); \
  } while(0)

#define bsg_fail() \
  do { \
    volatile int* ptr = &tohost; \
    *ptr = 0x3; \
    while(1); \
  } while(0)

#define bsg_putchar(ch) \
  do { \
    volatile int* ptr = &tohost; \
    *ptr = (ch << 8) | 0x2; \
    while(fromhost == 0); \
    fromhost = 0; \
  } while(0)

#define bsg_print_time() // nothing here for now

#define bsg_remote_ptr_io_store(x, y, val) \
  printf("store to io: %d\n", val)

#endif // _SPIKE_H_
