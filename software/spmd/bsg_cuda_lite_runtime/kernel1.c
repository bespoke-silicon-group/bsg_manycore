//This is the kernel with 1 arguments

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel1( int p0 ){
        
	int base = 0x44444444;
	if (p0 != base)
        	bsg_finish_x(IO_X_INDEX);
	else
		bsg_fail_x(IO_X_INDEX);
        return 0;
}
