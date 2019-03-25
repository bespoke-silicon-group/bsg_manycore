#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include <stdio.h>
#include <stdlib.h>
#include <machine/bsg_newlib_fs.h>

lfs_t bsg_newlib_fs;

int main() {
  bsg_set_tile_x_y();

  if ((bsg_x == 0) && (bsg_y == bsg_tiles_Y-1)) {
    // bsg_newlib_fs_init();
    lfs_format(&bsg_newlib_fs, &bsg_newlib_fs_cfg);
    lfs_mount(&bsg_newlib_fs, &bsg_newlib_fs_cfg);
    bsg_printf("(%0d, %0d): init done\n", bsg_x, bsg_y);

    const char write_buf[50] = "Hello! This is Little FS!\n";
    char *read_buf = (char *) malloc(50);

    FILE *stdinfile = fopen("stdin", "w");
    bsg_printf("(%d, %d): stdin opened: fd = %d\n", bsg_x, bsg_y, stdinfile);
    FILE *stdoutfile = fopen("stdout", "w");
    bsg_printf("(%d, %d): stdout opened: fd = %d\n", bsg_x, bsg_y, stdoutfile);
    FILE *stderrfile = fopen("stderr", "w");
    bsg_printf("(%d, %d): stderr opened: fd = %d\n", bsg_x, bsg_y, stderrfile);

    //size_t write_bytes = fwrite(write_buf, 1, 50, stdoutfile);
    //bsg_printf("(%d, %d): written %d bytes to stdout\n", bsg_x, bsg_y, write_bytes);
    //
    //int ret = fclose(stdinfile);
    //bsg_printf("(%d, %d): stdin closed: ret = %d\n", bsg_x, bsg_y, ret);
    //ret = fclose(stdoutfile);
    //bsg_printf("(%d, %d): stdout closed: ret = %d\n", bsg_x, bsg_y, ret);
    //ret = fclose(stderrfile);
    //bsg_printf("(%d, %d): stderr closed: ret = %d\n", bsg_x, bsg_y, ret);

    //stdoutfile = fopen("stdout", "r");
    //bsg_printf("(%d, %d): stdout opened for reading; fd = %d\n", bsg_x, bsg_y, stdoutfile);
    //size_t read_bytes = fread(read_buf, 1, 50, stdoutfile);
    //bsg_printf("(%d, %d): read %d bytes from stdout\n", bsg_x, bsg_y, read_bytes);
    //ret = fclose(stdoutfile);
    //bsg_printf("(%d, %d): stdout closed: ret = %d\n", bsg_x, bsg_y, ret);
    //bsg_printf("(%d, %d): %s\n", bsg_x, bsg_y, read_buf);

    //free(read_buf);
    //bsg_printf("(%d, %d): Read buffer freed, prints garabge...\n", bsg_x, bsg_y);
    //ret = bsg_printf("(%d, %d): %s\n", bsg_x, bsg_y, read_buf); // prints garbage

    bsg_finish();
  }

  bsg_wait_while(1);
}
