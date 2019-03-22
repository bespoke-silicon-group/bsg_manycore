//This is the kernel with 1 arguments

#include "bsg_manycore.h"

int  __attribute__ ((noinline)) kernel1( int p0 ){
        bsg_printf("Kernel1 param1=%08x\n", p0);
        return 0;
}
