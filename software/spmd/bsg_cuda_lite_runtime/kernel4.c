//This is the kernel with 4 arguments

#include "bsg_manycore.h"

int  __attribute__ ((noinline)) kernel4( int p0, int p1, int p2, int p3 ){
        bsg_printf("Kernel4 param4=%08x,%08x,%08x,%08x\n", p0, p1, p2, p3);
        return 0;
}
