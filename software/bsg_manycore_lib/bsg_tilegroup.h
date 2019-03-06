/** @file bsg_tilegroup.h
 *  @brief Functions and definitions for working with manycore tile groups
 */
#ifndef _BSG_TILEGROUP_H
#define _BSG_TILEGROUP_H

#include "bsg_manycore.h"

#define STRIPE __attribute__((address_space(1)))

// Passed from linker -- indicates start of striped arrays in DMEM
extern unsigned _striped_data_start;

// Runtime functions called by the LLVM pass
void extern_store(int STRIPE *arr_ptr, unsigned elem_size, unsigned val);
int extern_load(int STRIPE *arr_ptr, unsigned elem_size);


/* NOTE: It's usually a cardinal sin to include code in header files, but LLVM
 * needs the definitions of runtime functions avaliable so that the pass can
 * replace loads and stores -- these aren't avaliable via declarations. */
static inline volatile int *get_ptr_val(int STRIPE *arr_ptr, unsigned elem_size) {
    unsigned start_ptr = (unsigned) &_striped_data_start;
    unsigned ptr = (unsigned) arr_ptr;

    // We only need to care about the offset from the start of the .striped.data
    // section. Since data is aligned on word_size * G, we can calculate the
    // "index" into the overall .striped.data segment. In hardware, this would
    // be the same as caluclating the offset from a segment register
    unsigned index = ((ptr) - start_ptr) / elem_size;
    unsigned core_id = index % (group_size);
    unsigned local_addr = start_ptr + (index / group_size) * elem_size;

    // Get X & Y coordinates of the tile that holds the memory address
    unsigned tile_x = core_id / bsg_tiles_X;
    unsigned tile_y = core_id - (tile_x * bsg_tiles_X);

    // Construct the remote NPA: 01YY_YYYY_XXXX_XXPP_PPPP_PPPP_PPPP_PPPP
    unsigned remote_ptr_val = REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS |
                              tile_x << X_CORD_SHIFTS |
                              tile_y << Y_CORD_SHIFTS |
                              local_addr;
    // This check isn't strictly needed, but it's kept so that we can check the
    // performance effect
    unsigned ptr_val = (tile_x == bsg_x && tile_y == bsg_y) ?
        local_addr : remote_ptr_val;
#ifdef DEBUG
    bsg_printf("ID = %u, index = %u; striped_data_start = 0x%x\n",
            core_id, index, &_striped_data_start);
    bsg_printf("NPA=(%u, %u, 0x%x)\n", tile_x, tile_y, local_addr);
    bsg_printf("Final Pointer is 0x%x\n", ptr_val);
#endif
    return (volatile int *) ptr_val;
}

inline void extern_store(int STRIPE *arr_ptr, unsigned elem_size, unsigned val) {
#ifdef DEBUG
    bsg_printf("\nCalling extern_store(0x%x, %d, %d)\n", (unsigned) arr_ptr,
            elem_size, val);
#endif
    volatile int *ptr = get_ptr_val(arr_ptr, elem_size);
    *ptr = val;
}

inline int extern_load(int STRIPE *arr_ptr, unsigned elem_size) {
#ifdef DEBUG
    bsg_printf("\nCalling extern_load(0x%x, %d)\n",
            (unsigned) arr_ptr,
            elem_size);
#endif
    volatile int *ptr = get_ptr_val(arr_ptr, elem_size);
    return *ptr;
}


#endif // _BSG_TILEGROUP_H
