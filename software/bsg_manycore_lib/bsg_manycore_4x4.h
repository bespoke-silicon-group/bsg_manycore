#define bsg_tiles_X 4
#define bsg_tiles_Y 4

#define bsg_noc_ybits 3 // bsg_safe_clog2(tiles_Y+1) --> safe_clog2(5) --> 3
#define bsg_noc_xbits 2 // bsg_safe_clog2(tiles_X)   --> safe_clog2(4) --> 2

#include "bsg_manycore.h"
