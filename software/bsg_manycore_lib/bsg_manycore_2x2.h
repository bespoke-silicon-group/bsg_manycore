#define bsg_tiles_X 2
#define bsg_tiles_Y 2

#define bsg_noc_ybits 2 // bsg_safe_clog2(tiles_Y+1) --> safe_clog2(3) --> 2
#define bsg_noc_xbits 1 // bsg_safe_clog2(tiles_X)   --> safe_clog2(2) --> 1

#include "bsg_manycore.h"
