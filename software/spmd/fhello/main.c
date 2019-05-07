#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int main() {
  if ((__bsg_x == 0) && (__bsg_y == bsg_tiles_Y-1)) {
    char c;

    // Read from a file
    FILE *hello = fopen("hello.txt", "r");
    if(hello == NULL)
      return -1;

    while((c = fgetc(hello)) != '\n') {
      putchar(c);
    }
    putchar('\n');
    
    fclose(hello);
    return 0;
  }

  bsg_wait_while(1);
}
