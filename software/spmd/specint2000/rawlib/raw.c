#include "raw.h"
#include <stdio.h>

void timebegin() {
  printf("At begin: \n");
  bsg_print_time();
}

void timeend() {
  printf("At end: \n");
  bsg_print_time();
}
