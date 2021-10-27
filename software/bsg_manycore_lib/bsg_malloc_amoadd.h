#ifndef BSG_MALLOC_AMOADD_H
#define BSG_MALLOC_AMOADD_H
#include <stdlib.h>

extern size_t  __bsg_malloc_heap;
extern size_t  __bsg_malloc_heap_end;

static void * bsg_malloc_amoadd(size_t size) {
    size_t addr;
    asm volatile ("amoadd.w %[addr],%[size],(%[heap])"
                  : [addr] "=r" (addr)
                  : [size] "r" (size), [heap] "r" (&__bsg_malloc_heap));

    if (addr == __bsg_malloc_heap_end) {
        return (void*)(0xffffffff);
    }
    return (void*)addr;
}

#endif
