#ifndef _BSG_MANYCORE_HPP_
#define _BSG_MANYCORE_HPP_

#include <cstdint>
#include <bsg_manycore_arch.h>




/* 
 * Remote EVA poitner to a local address in a tile within tile group
 * param[in]  x             X coordinate of destination tile
 * param[in]  y             Y coordinate of destination tile
 * param[in]  local_addr    address of varialbe in tile's local dmem
 * @return    EVA address of remote variable
 */ 
template<typename T>
T *bsg_tile_group_remote_pointer(unsigned char x, unsigned char y, T* local_addr) {
        uintptr_t remote_prefix = (REMOTE_EPA_PREFIX << REMOTE_EPA_MASK_SHIFTS);
        uintptr_t y_bits = ((y) << Y_CORD_SHIFTS);
        uintptr_t x_bits = ((x) << X_CORD_SHIFTS);
        uintptr_t local_bits = reinterpret_cast<uintptr_t>(local_addr);
        return reinterpret_cast<T *>(remote_prefix | y_bits | x_bits | local_bits);
}



#endif // _BSG_MANYCORE_HPP_
