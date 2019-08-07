#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <bsg_manycore.h>

int varfunc(const char*, ...);

int main() {
  char title[] = "\n\nVPR FPGA Placement and Routing Program Version 4.00-spec"
                 "\nSource completed August 19, 1997.\n\n";
  int len = varfunc("%s", title);
  bsg_print_int(len);
  return 0;
}
