//This is the kernel with 4 arguments

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel4( int p0, int p1, int p2, int p3 ){
        int base = 0x44444444;
	int pass = 0;
	if (p0 != base)
		pass = -1;
	else if (p1 != (base + 1))
		pass = -1;
	else if (p2 != (base + 2))
		pass = -1;
	else if (p3 != (base + 3))
		pass = -1;
	
      if (pass == 0) {
        bsg_finish_x(IO_X_INDEX);
      }
      else {
        bsg_fail_x(IO_X_INDEX);
      }

        return 0;
}
