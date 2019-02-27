#include "fs.h"
#include "lfs_bd.h"

// Data mem allocation for FS
static uint8_t lfs_mem[BLOCK_SIZE*BLOCK_COUNT] __attribute__ ((section (".dram")));

// File system memory pointer
const uint8_t *lfs_ptr = lfs_mem;

// lfs static buffers
static uint8_t read_buffer[READ_SIZE];
static uint8_t prog_buffer[PROG_SIZE];
static uint8_t lookahead_buffer[LOOKAHEAD/8];
static uint8_t file_buffer[PROG_SIZE];

// LittleFS configuration
const struct lfs_config cfg = {
    // block device operations
    .read  = lfs_read,
    .prog  = lfs_prog,
    .erase = lfs_erase,
    .sync  = lfs_sync,

    // block device configuration
    .read_size   = FS_READ_SIZE,
    .prog_size   = FS_PROG_SIZE,
    .block_size  = FS_BLOCK_SIZE,
    .block_count = FS_BLOCK_COUNT,
    .lookahead   = FS_LOOKAHEAD,

    // buffers for fs operations
    .read_buffer      = read_buffer,
    .prog_buffer      = prog_buffer,
    .lookahead_buffer = lookahead_buffer,
    .file_buffer      = file_buffer
};
