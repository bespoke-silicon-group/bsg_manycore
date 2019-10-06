#ifndef __host__
#include "raw.h"
#endif

#include <stdio.h>

void timebegin() {
  printf("At begin: \n");

  #ifdef __spike__
    replace_spike_call(print_time);
  #else
    bsg_print_time();
  #endif
}

void timeend() {
  printf("At end: \n");

  #ifdef __spike__
    replace_spike_call(print_time);
  #else
    bsg_print_time();
  #endif
}
