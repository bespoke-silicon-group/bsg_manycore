/** @file bsg_tilegroup.h
 *  @brief Functions and definitions for working with manycore tile groups
 */
#ifndef _BSG_TILEGROUP_H
#define _BSG_TILEGROUP_H

#include "bsg_set_tile_x_y.h"
#include "bsg_manycore.h"

#define STRIPE __attribute__((address_space(1)))

// Passed from linker -- indicates start of striped arrays in DMEM
extern unsigned _bsg_striped_data_start;

/* NOTE: It's usually a cardinal sin to include code in header files, but LLVM
 * needs the definitions of runtime functions avaliable so that the pass can
 * replace loads and stores -- these aren't avaliable via declarations. */
 static volatile void *get_ptr_val(void STRIPE *arr_ptr, unsigned elem_size) {
    unsigned start_ptr = (unsigned) &_bsg_striped_data_start;
    unsigned ptr = (unsigned) arr_ptr;

    // We only need to care about the offset from the start of the .striped.data
    // section. Since data is aligned on word_size * G, we can calculate the
    // "index" into the overall .striped.data segment. In hardware, this would
    // be the same as caluclating the offset from a segment register
    unsigned index = ((ptr) - start_ptr) / elem_size;
    unsigned core_id = index % (bsg_group_size);
    unsigned local_addr = start_ptr + (index / bsg_group_size) * elem_size;

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
#ifdef TILEGROUP_DEBUG
    bsg_printf("ID = %u, index = %u; striped_data_start = 0x%x\n",
            core_id, index, &_bsg_striped_data_start);
    bsg_printf("NPA=(%u, %u, 0x%x)\n", tile_x, tile_y, local_addr);
    bsg_printf("Final Pointer is 0x%x\n", ptr_val);
#endif
    return (volatile int *) ptr_val;
}

__attribute__((always_inline)) void extern_store_int(int STRIPE *arr_ptr, unsigned elem_size, unsigned val) {
#ifdef TILEGROUP_DEBUG
    bsg_printf("\nCalling extern_store_int(0x%x, %d, %d)\n", (unsigned) arr_ptr,
            elem_size, val);
#endif
    volatile int *ptr = get_ptr_val(arr_ptr, elem_size);
    *ptr = val;
}

__attribute__((always_inline)) void extern_store_short(int STRIPE *arr_ptr, unsigned elem_size, short val) {
#ifdef TILEGROUP_DEBUG
    bsg_printf("\nCalling extern_store_short(0x%x, %d, %d)\n", (unsigned) arr_ptr,
            elem_size, val);
#endif
    volatile short *ptr = (volatile short *) get_ptr_val(arr_ptr, elem_size);
    *ptr = val;
}

__attribute__((always_inline)) void extern_store_char(int STRIPE *arr_ptr, unsigned elem_size, char val) {
#ifdef TILEGROUP_DEBUG
    bsg_printf("\nCalling extern_store_char(0x%x, %d, %d)\n", (unsigned) arr_ptr,
            elem_size, val);
#endif
    volatile char *ptr = (volatile char *) get_ptr_val(arr_ptr, elem_size);
    *ptr = val;
}

__attribute__((always_inline)) int extern_load_int(int STRIPE *arr_ptr, unsigned elem_size) {
#ifdef TILEGROUP_DEBUG
    bsg_printf("\nCalling extern_load_int(0x%x, %d)\n",
            (unsigned) arr_ptr,
            elem_size);
#endif
    volatile int *ptr = get_ptr_val(arr_ptr, elem_size);
    return *ptr;
}

__attribute__((always_inline)) short extern_load_short(int STRIPE *arr_ptr, unsigned elem_size) {
#ifdef TILEGROUP_DEBUG
    bsg_printf("\nCalling extern_load_short(0x%x, %d)\n",
            (unsigned) arr_ptr,
            elem_size);
#endif
    volatile short *ptr = (volatile short *) get_ptr_val(arr_ptr, elem_size);
    return *ptr;
}

__attribute__((always_inline)) char extern_load_char(int STRIPE *arr_ptr, unsigned elem_size) {
#ifdef TILEGROUP_DEBUG
    bsg_printf("\nCalling extern_load_char(0x%x, %d)\n",
            (unsigned) arr_ptr,
            elem_size);
#endif
    volatile char *ptr = (volatile char *) get_ptr_val(arr_ptr, elem_size);
    return *ptr;
}

#endif // _BSG_TILEGROUP_H
