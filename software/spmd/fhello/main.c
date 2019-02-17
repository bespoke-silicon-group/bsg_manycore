#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "lfs.h"
#include "lfs_bd.h"
#include <string.h>

// 2Kb file system memory
// Block size cannot be less than 128 due to
// LittleFS intrinsics.
#define READ_SIZE 32
#define PROG_SIZE 32
#define BLOCK_SIZE 128
#define BLOCK_COUNT 16
#define LOOKAHEAD 32

lfs_t           lfs; // littlefs data structure
lfs_file_t      file; // littlefs file
struct lfs_info file_info; // file info structure

// Data mem allocation for FS
uint8_t lfs_mem[BLOCK_SIZE*BLOCK_COUNT] __attribute__ ((section (".dram")));

// File system memory pointer
uint8_t *lfs_ptr = lfs_mem;

// lfs static buffers
static char read_buffer[READ_SIZE];
static char prog_buffer[PROG_SIZE];
static char lookahead_buffer[LOOKAHEAD/8];
static char file_buffer[PROG_SIZE];

// LittleFS configuration
const struct lfs_config cfg = {
    // block device operations
    .read  = lfs_read,
    .prog  = lfs_prog,
    .erase = lfs_erase,
    .sync  = lfs_sync,

    // block device configuration
    .read_size = READ_SIZE,
    .prog_size = PROG_SIZE,
    .block_size = BLOCK_SIZE,
    .block_count = BLOCK_COUNT,
    .lookahead = LOOKAHEAD,

    .read_buffer = read_buffer,
    .prog_buffer = prog_buffer,
    .lookahead_buffer = lookahead_buffer,
    .file_buffer = file_buffer
};

int main()
{
    bsg_set_tile_x_y();

    if ((bsg_x == 0) && (bsg_y == bsg_tiles_Y-1)) {
        const char filename[20] = "hello.txt";
        const char write_buf[50] = "Hello! This is Little FS!\n";
        char read_buf[20] = "";

        // format and mount
        if(lfs_format(&lfs, &cfg) < 0) 
            bsg_printf("(%0d, %0d): format error\n", bsg_x, bsg_y);
        else
            bsg_printf("(%0d, %0d): formatted the fs...\n", bsg_x, bsg_y);
        if(lfs_mount(&lfs, &cfg) < 0) 
            bsg_printf("(%0d, %0d): mount error\n", bsg_x, bsg_y);
        else
            bsg_printf("(%0d, %0d): file system mounted...\n", bsg_x, bsg_y);

        // write sequence: open, write & close
        // Close is important as writes aren't commited until close!!!
        if(lfs_file_open(&lfs, &file, filename, LFS_O_RDWR | LFS_O_CREAT) < 0)
            bsg_printf("(%0d, %0d): file open error\n", bsg_x, bsg_y);
        else
            bsg_printf("(%0d, %0d): file created for writing...\n", bsg_x, bsg_y);
        if(lfs_file_write(&lfs, &file, write_buf, sizeof(write_buf)) < 0)
            bsg_printf("(%0d, %0d): file write error\n", bsg_x, bsg_y);
        else
            bsg_printf("(%0d, %0d): file written...\n", bsg_x, bsg_y);
        if(lfs_file_close(&lfs, &file) < 0)
            bsg_printf("(%0d, %0d): file close error\n", bsg_x, bsg_y);
        else
            bsg_printf("(%0d, %0d): file closed...\n", bsg_x, bsg_y);

        // open, read & close
        // find the file size and read it into read buffer
        if(lfs_file_open(&lfs, &file, filename, LFS_O_RDONLY) < 0)
            bsg_printf("(%0d, %0d): file open error\n", bsg_x, bsg_y);
        else
            bsg_printf("(%0d, %0d): file opened for reading...\n", bsg_x, bsg_y);
        if(lfs_stat(&lfs, filename, &file_info) < 0)
            bsg_printf("(%0d, %0d): file info error\n", bsg_x, bsg_y);
        if(lfs_file_read(&lfs, &file, read_buf, file_info.size) < 0)
            bsg_printf("(%0d, %0d): file read error\n", bsg_x, bsg_y);
        else
            bsg_printf("(%0d, %0d): file read...\n", bsg_x, bsg_y);
        if(lfs_file_close(&lfs, &file) < 0)
            bsg_printf("(%0d, %0d): file close error\n", bsg_x, bsg_y);
        else
            bsg_printf("(%0d, %0d): file closed...\n", bsg_x, bsg_y);

        // unmount
        if(lfs_unmount(&lfs) < 0)
            bsg_printf("(%0d, %0d): Unmounting error\n", bsg_x, bsg_y);
        else
            bsg_printf("(%0d, %0d): file system unmounted...\n", bsg_x, bsg_y);

        // Should be Hello World!
        bsg_printf("(%d, %d): %s", bsg_x, bsg_y, read_buf);
        bsg_finish();
    }

    bsg_wait_while(1);
}

