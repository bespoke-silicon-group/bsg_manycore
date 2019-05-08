#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int main() {
  if ((__bsg_x == 0) && (__bsg_y == bsg_tiles_Y-1)) {
    char* line = (char*) malloc(128);

    FILE* hello = fopen("hello.txt", "r");

    if(fgets(line, 128, hello) != NULL) {
      printf("%s", line);
    } else {
      printf("readline failed\n");
    }

    return 0;
  }

  bsg_wait_while(1);
}
