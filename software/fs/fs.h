#ifndef BSG_FS_H
#define BSG_FS_H

#include "lfs.h"

// 2Kb file system memory
// Block size cannot be less than 128 due to
// LittleFS intrinsics.
#define FS_READ_SIZE 32
#define FS_PROG_SIZE 32
#define FS_BLOCK_SIZE 128
#define FS_BLOCK_COUNT 16
#define FS_LOOKAHEAD 32

// file system structure
extern lfs_t fs;

// file system configuration
extern const struct lfs_config cfg;

#endif // BSG_FS_H
