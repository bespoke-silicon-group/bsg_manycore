#include <stdlib.h>
#include <machine/bsg_newlib_fs.h>

#ifdef __spike__

extern int tohost;

#define bsg_finish() \
  do { \
    volatile int* ptr = &tohost; \
    *ptr = 0x1; \
    while(1); \
  } while(0)

#define bsg_fail() \
  do { \
    volatile int* ptr = &tohost; \
    *ptr = 0x0; \
    while(1); \
  } while(0)

#define bsg_putchar(ch) \
  do { \
    volatile int* ptr = &tohost; \
    *ptr = 0xaa; \
    while(1); \
  } while(0)

#else // ifndef __spike__

#include "bsg_manycore.h"

#endif // __spike__

void bsg_newlib_init(void) {
  // Init file system
  if(bsg_newlib_fs_init() < 0) {
    exit(EXIT_FAILURE);
  }
}

void bsg_newlib_exit(int exit_status) {
  if(exit_status == EXIT_SUCCESS) {
    bsg_finish();
  } else {
    bsg_fail();
  }
}

void bsg_newlib_sendchar(char ch) {
  bsg_putchar(ch);
}
