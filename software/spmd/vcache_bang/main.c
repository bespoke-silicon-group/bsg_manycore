#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include <stdint.h>

extern uint32_t* _bsg_dram_end_addr;

int main() {
  bsg_set_tile_x_y();

  if((__bsg_x == 0) && (__bsg_y == 1)) {
    for(uint32_t* i = _bsg_dram_end_addr; (uint32_t)i < __bsg_vcache_size; i++) {
      *(i) = (uint32_t)i;
    }

    for(uint32_t* i = _bsg_dram_end_addr; (uint32_t)i < __bsg_vcache_size; i++) {
      if(*(i) != (uint32_t)i) bsg_fail();
    }

    bsg_finish();
  }

  bsg_wait_while(1);
}

