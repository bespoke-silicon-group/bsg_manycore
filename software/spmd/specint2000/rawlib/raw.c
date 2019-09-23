#ifndef __host__
#include "raw.h"
#endif

#include <stdio.h>

void timebegin() {
  printf("At begin: \n");

#ifndef __host__
  bsg_print_time();
#endif
}

void timeend() {
  printf("At end: \n");

#ifndef __host__
  bsg_print_time();
#endif
}
