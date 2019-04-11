#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <machine/bsg_newlib_fs.h>

int main() {
  bsg_set_tile_x_y();

  if ((__bsg_x == 0) && (__bsg_y == bsg_tiles_Y-1)) {
    if(bsg_newlib_fs_init() < 0)
      bsg_printf("bsg_newlib_fs_init failed!\n");

    FILE *stdinfile = fopen("stdin", "w");
    bsg_printf("(%d, %d): stdin opened: fd = %x\n", bsg_x, bsg_y, stdinfile);
    FILE *stdoutfile = fopen("stdout", "w");
    bsg_printf("(%d, %d): stdout opened: fd = %x\n", bsg_x, bsg_y, stdoutfile);
    FILE *stderrfile = fopen("stderr", "w");
    bsg_printf("(%d, %d): stderr opened: fd = %x\n", bsg_x, bsg_y, stderrfile);


    const char* msg = "Hello! This is Little FS!";
    size_t read_buf_size = strlen(msg) + 1;

    size_t write_bytes = fprintf(stdoutfile, msg);
    bsg_printf("(%d, %d): written %d chars to stdout\n", bsg_x, bsg_y, write_bytes);
    
    int ret = fclose(stdinfile);
    bsg_printf("(%d, %d): stdin closed: ret = %d\n", bsg_x, bsg_y, ret);
    ret = fclose(stdoutfile);
    bsg_printf("(%d, %d): stdout closed: ret = %d\n", bsg_x, bsg_y, ret);
    ret = fclose(stderrfile);
    bsg_printf("(%d, %d): stderr closed: ret = %d\n", bsg_x, bsg_y, ret);

    char *read_buf = (char *) malloc(sizeof(char) * read_buf_size);
    stdoutfile = fopen("stdout", "r");
    bsg_printf("(%d, %d): stdout opened for reading; fd = %x\n", bsg_x, bsg_y, stdoutfile);
    size_t read_bytes = fread(read_buf, 1, read_buf_size, stdoutfile);
    bsg_printf("(%d, %d): read %d bytes from stdout\n", bsg_x, bsg_y, read_bytes);
    ret = fclose(stdoutfile);
    bsg_printf("(%d, %d): stdout closed: ret = %d\n", bsg_x, bsg_y, ret);

    read_buf[read_buf_size-1] = NULL; // NULL termination for printing read buf as a string
    bsg_printf("(%d, %d): %s\n", bsg_x, bsg_y, read_buf);

    bsg_finish();
  }

  bsg_wait_while(1);
}
