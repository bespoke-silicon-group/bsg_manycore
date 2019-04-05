//This is the kernel with 12 arguments (4 come from stack pointer)

#include "bsg_manycore.h"

int  __attribute__ ((noinline)) kernel12( int p0, int p1, int p2, int p3, int p4, int p5, int p6, int p7, int p8, int p9, int p10, int p11){
        //bsg_printf("Kernel8 param8=%08x,%08x,%08x,%08x,%08x, %08x,%08x,%08x \n", p0, p1, p2, p3, p4, p5, p6, p7, p8);
        bsg_remote_ptr_io_store(IO_X_INDEX,0x1260,p8);
        bsg_remote_ptr_io_store(IO_X_INDEX,0x1264,p9);
        bsg_remote_ptr_io_store(IO_X_INDEX,0x1268,p10);
        bsg_remote_ptr_io_store(IO_X_INDEX,0x126c,p11);
        return 0;
}
