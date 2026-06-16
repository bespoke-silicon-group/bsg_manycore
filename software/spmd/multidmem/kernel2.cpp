
#include <bsg_manycore.h>

static const int data[16] __attribute__ ((section (".kernel2_dmem"))) = {
    0x2aaa, 0x2aaa, 0x2aaa, 0x2aaa,
    0x2bbb, 0x2bbb, 0x2bbb, 0x2bbb,
    0x2ccc, 0x2ccc, 0x2ccc, 0x2ccc,
    0x2ddd, 0x2ddd, 0x2ddd, 0x2ddd
};

int kernel2(void) {
    bsg_printf("Hello from kernel 2!\n");
    bsg_printf("rodata is located at: %x\n", &data[0]);
    for (int i = 0; i < 16; i++) {
        if (i % 4 == 0) {
            bsg_printf("\n\t");
        }
        bsg_printf("%x\t", data[i]);
    }
    bsg_printf("\n");
    return 0;
}

