#include <stdio.h>
#include <string.h>
#include "lfs.h"
#include "lfs_bd.h"

// 2Kb file system memory
// Block size cannot be less than 128 due to
// LittleFS intrinsics.
#define BLOCK_SIZE 128
#define BLOCK_COUNT 16

lfs_t           lfs; // littlefs data structure
lfs_file_t      file; // littlefs file
struct lfs_info file_info; // file info structure
uint8_t         lfs_mem[BLOCK_SIZE*BLOCK_COUNT]; // Data mem allocation for FS

// File system memory pointer
uint8_t *lfs_ptr = lfs_mem;

// LittleFS configuration
const struct lfs_config cfg = {
    // block device operations
    .read  = lfs_read,
    .prog  = lfs_prog,
    .erase = lfs_erase,
    .sync  = lfs_sync,

    // block device configuration
    .read_size = 32,
    .prog_size = 32,
    .block_size = BLOCK_SIZE,
    .block_count = BLOCK_COUNT,
    .lookahead = 32,
};

int main() {
    const char filename[20] = "hello.txt";
    const char write_buf[20] = "Hello World!\n";
    char read_buf[20] = "";

    // format and mount
    if(lfs_format(&lfs, &cfg) < 0) 
        printf("format error\n");
    if(lfs_mount(&lfs, &cfg) < 0) 
        printf("mount error\n");

    // write sequence: open, write & close
    // Close is important as writes aren't commited until close!!!
    if(lfs_file_open(&lfs, &file, filename, LFS_O_RDWR | LFS_O_CREAT) < 0)
        printf("file open error\n");
    if(lfs_file_write(&lfs, &file, write_buf, sizeof(write_buf)) < 0)
        printf("file write error\n");
    if(lfs_file_close(&lfs, &file) < 0)
        printf("file close error\n");

    // open, read & close
    // find the file size and read it into read buffer
    if(lfs_file_open(&lfs, &file, filename, LFS_O_RDONLY) < 0)
        printf("file open error\n");
    if(lfs_stat(&lfs, filename, &file_info) < 0)
        printf("file info error\n");
    if(lfs_file_read(&lfs, &file, read_buf, file_info.size) < 0)
        printf("file read error\n");
    if(lfs_file_close(&lfs, &file) < 0)
        printf("file close error\n");

    // unmount
    if(lfs_unmount(&lfs) < 0)
        printf("Unmounting error\n");

    // Should be Hello World!
    printf(read_buf);
    return 0;
}
