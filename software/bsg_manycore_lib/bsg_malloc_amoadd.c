#include "bsg_malloc_amoadd.h"

#ifndef BSG_MALLOC_HEAP_SIZE
#define BSG_MALLOC_HEAP_SIZE (1024*1024*512)
#endif

extern size_t _bsg_dram_end_addr;

__attribute__((section(".dram")))
size_t __bsg_malloc_heap = (size_t)&_bsg_dram_end_addr;
size_t __bsg_malloc_heap_end = ((size_t)&_bsg_dram_end_addr) + BSG_MALLOC_HEAP_SIZE;
