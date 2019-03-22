//This is the kernel with 8 arguments

#include "bsg_manycore.h"

int  __attribute__ ((noinline)) kernel8( int p0, int p1, int p2, int p3, int p4, int p5, int p6, int p7 ){
        bsg_printf("Kernel8 param8=%08x,%08x,%08x,%08x,%08x, %08x,%08x,%08x \n", p0, p1, p2, p3, p4, p5, p6, p7);
        return 0;
}
