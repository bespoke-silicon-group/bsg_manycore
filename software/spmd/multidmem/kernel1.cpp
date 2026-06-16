
#include <bsg_manycore.h>

static const int data[16] __attribute__ ((section (".kernel1_dmem"))) = {
    0x1aaa, 0x1aaa, 0x1aaa, 0x1aaa,
    0x1bbb, 0x1bbb, 0x1bbb, 0x1bbb,
    0x1ccc, 0x1ccc, 0x1ccc, 0x1ccc,
    0x1ddd, 0x1ddd, 0x1ddd, 0x1ddd
};

int kernel1(void) {
    bsg_printf("Hello from kernel 1!\n");
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

