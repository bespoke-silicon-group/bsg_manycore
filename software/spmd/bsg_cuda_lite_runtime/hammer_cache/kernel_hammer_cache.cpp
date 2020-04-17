/*******************************************************************/
/* This kernel is designed to overload the memory system.          */
/* It forces cache evictions by striding to the line in the        */
/* same set of the same cache and doing a single store.            */
/* It then stores a word to an address maping to the evicted line. */
/*******************************************************************/

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define bsg_n (bsg_tiles_X * bsg_tiles_Y)

static
int hammer_cache(int *dram_cache_aligned,
                 int cache_line_size_words,
                 int n_caches,
                 int n_ways,
                 int n_sets)
{
    int *base = &dram_cache_aligned[cache_line_size_words*bsg_id];
    int *baddr = base;
    base[1] = 0xdeadbeef;
    for (int i = 0; i < n_ways+1; i++) {
        *baddr = i;
        // get next address that maps to the same set
        baddr = &baddr[cache_line_size_words * n_caches * n_sets];
    }
    // load from the original line - should have been evicted
    return base[1] == 0xdeadbeef;
}

extern "C" __attribute__ ((noinline))
int kernel_hammer_cache(
    int * dram_cache_aligned,
    int   cache_line_size_words,
    int   n_caches,
    int   n_ways,
    int   n_sets,
    int   n_hammers
    ) {

    int *base = dram_cache_aligned;
    for (int i = 0; i < n_hammers; i++) {
        hammer_cache(base, cache_line_size_words, n_caches, n_ways, n_sets);
        // shift up bsg_n caches
        base = &base[cache_line_size_words * bsg_n];
    }

    return 0;
}
