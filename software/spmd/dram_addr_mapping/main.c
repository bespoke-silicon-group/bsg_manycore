
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

//dram_ch_addr_width_p set to DRAM_CH_ADDR_BITS-2
#define DRAM_CH_ADDR_BITS 18
int main()
{

  bsg_set_tile_x_y();

  //This should be send to column 0
  bsg_remote_int_ptr pData = bsg_dram_ptr( 0x0 ); 
  *pData = 0x1;

  //This should be send to column 1
  pData = bsg_dram_ptr( 1 << DRAM_CH_ADDR_BITS ); 
  *pData = 0x2;

  //This should be send to column 2
  bsg_dram_store( (2<<DRAM_CH_ADDR_BITS), 0x3);

  if ((bsg_x == bsg_tiles_X-1) && (bsg_y == bsg_tiles_Y-1))
    bsg_finish();

  bsg_wait_while(1);
}

