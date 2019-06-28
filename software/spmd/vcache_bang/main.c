#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

// Address where dram contents end
extern uint32_t _bsg_dram_end_addr;

// Very last address in vcache
uint32_t vcache_end_addr = 0x80000000 + __bsg_vcache_size - 4;

int main() {
  bsg_set_tile_x_y();

  if((__bsg_x == 0) && (__bsg_y == 0)) {
    for(uint32_t* i = &_bsg_dram_end_addr; (uint32_t)i < vcache_end_addr; i++) {
      *(i) = (uint32_t)i;
    }

    for(uint32_t* i = &_bsg_dram_end_addr; (uint32_t)i < vcache_end_addr; i++) {
      if(*(i) != (uint32_t)i) bsg_fail();
    }

    bsg_finish();
  }

  bsg_wait_while(1);
}
