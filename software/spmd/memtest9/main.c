/**
 *    memtest9
 *
 *    testing eviction on each vcache bank.
 *
 */


#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define BLOCK_SIZE 8

int dram_addr[BLOCK_SIZE];

void gen_dram_addr(int tag, int bank)
{
  for (int b = 0; b < BLOCK_SIZE; b++)
  {
    dram_addr[b] = (3<<30) + (tag<<17) + (bank<<5) + (b<<2);
  } 
}


void write_block(int tag, int bank)
{
  gen_dram_addr(tag, bank);
  for (int b = 0; b < BLOCK_SIZE; b++)
  {
    bsg_dram_store(dram_addr[b], dram_addr[b]);
  }
}


void read_block(int tag, int bank)
{
  gen_dram_addr(tag, bank);
  for (int b = 0; b < BLOCK_SIZE; b++)
  {
    int load_val = -1;
    bsg_dram_load(dram_addr[b], load_val);
    if (load_val != dram_addr[b])
    {
      //bsg_printf("[BSG_FAIL] expected: %x, actual: %x\n", dram_addr[b], load_val);
      bsg_fail();
    }
  } 
}


int main()
{
  bsg_set_tile_x_y();

  if (__bsg_x == 0 && __bsg_y == 0) 
  {
    bsg_print_stat(0);
    // testing bank 0~7
    for (int i = 0; i < 8; i++)
    {
      if (i % 2 == 0)
      {
        write_block(1,i);
        write_block(3,i);
        write_block(7,i);
        read_block(1,i);
        read_block(3,i);
        read_block(7,i);
      }
      else
      {
        write_block(0,i);
        write_block(2,i);
        write_block(6,i);
        read_block(0,i);
        read_block(2,i);
        read_block(6,i);
      }
    }

    // bank 8
    write_block(0,0);
    write_block(1,1);
    write_block(2,0);
    write_block(3,1);
    read_block(0,0);
    read_block(1,1);
    read_block(2,0);
    read_block(3,1);

    bsg_print_stat(0xdead);

    bsg_finish();
  }

  bsg_wait_while(1);
}

