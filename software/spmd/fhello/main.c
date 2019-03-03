#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#include <stdio.h>
#include <machine/bsg_newlib_fs.h>
#include <machine/bsg_newlib_fdtable.h>

lfs_t bsg_newlib_fs;

int main() {
  bsg_set_tile_x_y();

  for(int i=0; i < BSG_NEWLIB_MAX_FDS; i++)
    bsg_newlib_free_fd(i);
  
  const char write_buf[50] = "Hello! This is Newlib Little FS!\n";
  char read_buf[50] = "";

  if ((bsg_x == 0) && (bsg_y == bsg_tiles_Y-1)) {
    // Format and mount: can be moved to crt.S so that filesystem is mounted
    // in the beginning of every program
    if(lfs_format(&bsg_newlib_fs, &bsg_newlib_fs_cfg) < 0) 
        bsg_printf("(%0d, %0d): format error\n", bsg_x, bsg_y);
    else
        bsg_printf("(%0d, %0d): formatted the fs...\n", bsg_x, bsg_y);
    if(lfs_mount(&bsg_newlib_fs, &bsg_newlib_fs_cfg) < 0) 
        bsg_printf("(%0d, %0d): mount error\n", bsg_x, bsg_y);
    else
        bsg_printf("(%0d, %0d): file system mounted...\n", bsg_x, bsg_y);

    int test_fd = open("test.txt", LFS_O_RDWR | LFS_O_CREAT);
    bsg_printf("(%d, %d): fd = %d\n", bsg_x, bsg_y, test_fd);
    int bytes = write(test_fd, write_buf, sizeof(write_buf));
    bsg_printf("(%d, %d): write bytes = %d\n", bsg_x, bsg_y, bytes);
    bsg_printf("(%d, %d): file closed ret = %d\n", bsg_x, bsg_y, close(test_fd));

    test_fd = open("test.txt", LFS_O_RDONLY);
    bsg_printf("(%d, %d): fd = %d\n", bsg_x, bsg_y, test_fd);
    bytes = read(test_fd, read_buf, sizeof(write_buf));
    bsg_printf("(%d, %d): read bytes = %d\n", bsg_x, bsg_y, bytes);
    bsg_printf("(%d, %d): file closed ret = %d\n", bsg_x, bsg_y, close(test_fd));

    // Should be Hello World!
    bsg_printf("(%d, %d): %s", bsg_x, bsg_y, read_buf);
    bsg_finish();
  }

  bsg_wait_while(1);
}
