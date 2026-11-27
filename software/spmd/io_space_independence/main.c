#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

// 0(rs1) <- rs2
#define io_write(rs1, rs2) ({ \
  __asm__ __volatile__ (".insn r 0b0100011, 0b111, 0x0, x0, %0, %1" : : "r" (rs1), "r" (rs2)); \
  })

// rd <- 0(rs1)
#define io_read(rd, rs1) ({ \
  __asm__ __volatile__ (".insn i 0b0000011, 0b111, %0, %1, 0x0" : "=r" (rd) : "r" (rs1)); \
  })

unsigned dram_var __attribute__((section(".dram")));
unsigned dmem_var __attribute__((section(".dmem")));

int main()
{
  unsigned read_val = -1U;
  unsigned expected_val = 0xDEADDEAD;
  unsigned io_val = 0x123;
  bsg_set_tile_x_y();

  dram_var = expected_val;
  dmem_var = expected_val;

  io_write(&dram_var, io_val);
  io_write(&dmem_var, io_val);
  // Check if IO writes will affect regular memory values
  if(dram_var != expected_val)
    bsg_fail();
  if(dmem_var != expected_val)
    bsg_fail();

  dram_var = expected_val;
  dmem_var = expected_val;
  // Check if regular memory write will affect IO values
  io_read(read_val, &dram_var);
  if(read_val != io_val)
    bsg_fail();
  io_read(read_val, &dmem_var);
  if(read_val != io_val)
    bsg_fail();

  bsg_finish();
  bsg_wait_while(1);
}

