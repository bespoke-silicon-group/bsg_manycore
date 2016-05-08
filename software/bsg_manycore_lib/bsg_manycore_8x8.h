#define bsg_tiles_X 8
#define bsg_tiles_Y 8

#define bsg_noc_ybits 4 // bsg_safe_clog2(tiles_Y+1) --> safe_clog2(9) --> 4
#define bsg_noc_xbits 3 // bsg_safe_clog2(tiles_X)   --> safe_clog2(8) --> 3

#include "bsg_manycore.h"
