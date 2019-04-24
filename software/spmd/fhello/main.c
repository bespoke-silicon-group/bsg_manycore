#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main() {
  if ((__bsg_x == 0) && (__bsg_y == bsg_tiles_Y-1)) {
    FILE *hello = fopen("hello.txt", "r");
    if(hello == NULL)
      bsg_printf("file open error!\n");

    char *line = (char *) malloc(sizeof(char) * 128);

    if(fgets(line, 128, hello) != NULL) {
      bsg_printf("%s\n", line);
    } else {
      bsg_printf("Error reading file\n");
    }

    fclose(hello);
    bsg_finish();
  }

  bsg_wait_while(1);
}
