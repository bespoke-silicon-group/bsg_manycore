#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <bsg_manycore.h>

int varfunc(const char*, ...) __attribute__((noinline));

int main(int argc, char** argv) {
  char title[] = "\n\nVPR FPGA Placement and Routing Program Version 4.00-spec"
                 "\nSource completed August 19, 1997.\n\n ";

  int len = varfunc("%s", title);
  bsg_print_int(len);
  return 0;
}
