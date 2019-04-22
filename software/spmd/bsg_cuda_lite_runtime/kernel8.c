//This is the kernel with 8 arguments

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

int  __attribute__ ((noinline)) kernel8( int p0, int p1, int p2, int p3, int p4, int p5, int p6, int p7 ){
        //bsg_printf("Kernel8 param8=%08x,%08x,%08x,%08x,%08x, %08x,%08x,%08x \n", p0, p1, p2, p3, p4, p5, p6, p7);
        // hardcoded arguments
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
	else if (p4 != (base + 4))
		pass = -1;

	else if (p5 != (base + 5))
		pass = -1;
	else if (p6 != (base + 6))
		pass = -1;

	else if (p7 != (base + 7))
		pass = -1;

	
      if (pass == 0) {
        bsg_finish_x(IO_X_INDEX);
      }
      else {
        bsg_fail_x(IO_X_INDEX);
      }


	return 0;
}
