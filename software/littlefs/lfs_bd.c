#include "lfs_bd.h"
#include <string.h>

int lfs_read(const struct lfs_config *c, lfs_block_t block, lfs_off_t off
        , void *buffer, lfs_size_t size) {
    memcpy(buffer, lfs_ptr + (block * c->block_size) + off, size);
    return 0;
}

int lfs_prog(const struct lfs_config *c, lfs_block_t block, lfs_off_t off
        , const void *buffer, lfs_size_t size) {
	memcpy(lfs_ptr + (block * c->block_size) + off, buffer, size);
    return 0;
}

int lfs_erase(const struct lfs_config *c, lfs_block_t block) {
    memset(lfs_ptr + (block * c->block_size), 0, c->block_size);
    return 0;
}

int lfs_sync(const struct lfs_config *c) {
    (void) (c); // unused
	return 0;
}
