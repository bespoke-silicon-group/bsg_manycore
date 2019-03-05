extern int bsg_x;
extern int bsg_y;
// These exist so that LLVM has resolution about array size
int bsg_X_len = bsg_tiles_X;
int bsg_Y_len = bsg_tiles_Y;
int bsg_group_size = group_size;

int bsg_set_tile_x_y();
