#include <stdint.h>
#include <stdlib.h>
#include <bp_utils.h>

#ifndef NUM_ELEMENTS
#define NUM_ELEMENTS 8
#endif

#ifndef BSG_TILES_X
#define BSG_TILES_X 2
#endif

#ifndef BSG_TILES_Y
#define BSG_TILES_Y 2
#endif

#define BSG_TOTAL_TILES BSG_TILES_X * BSG_TILES_Y

int interrupt_taken;

__attribute__((interrupt))
void trap_handler(void) {
  // Disable interrupts
  uint64_t mstatus = 0;
   __asm__ __volatile__ ("csrw mstatus, %0" : : "r" (mstatus));
  interrupt_taken = 1;
}

void main() {
  /*********************
   Interrupt setup
  **********************/
  // Enable only software interrupts
  uint64_t mie = 1 << 3;
  // Enable M-mode interrupts
  uint64_t mstatus = 1 << 3;
  __asm__ __volatile__ ("csrw mie, %0": : "r" (mie));
  __asm__ __volatile__ ("csrw mstatus, %0" : : "r" (mstatus));

  // Set a alternate trap handler
  __asm__ __volatile__ ("csrw mtvec, %0": : "r" (&trap_handler));
  
  // Until interrupt is taken, this should be zero
  interrupt_taken = 0;

  /***********************
   Enable all domains
  ***********************/
  *hio_mask_addr = 0xFFF;

  /*******************************************
   Create 2 8x4 matrices and compute their sum
  ********************************************/
  uint32_t matrix0[BSG_TOTAL_TILES][NUM_ELEMENTS], matrix1[BSG_TOTAL_TILES][NUM_ELEMENTS], matrix2[BSG_TOTAL_TILES][NUM_ELEMENTS];
  for (uint32_t i = 0; i < BSG_TOTAL_TILES; i++) {
    for (uint32_t j = 0; j < NUM_ELEMENTS; j++) {
      matrix0[i][j] = j + i;
      matrix1[i][j] = j - i;
      matrix2[i][j] = matrix0[i][j] + matrix1[i][j];
    }
  }

  /*********************************************
   Send the input matrices to the correct tiles
   | 0 | 1 |
   | 2 | 3 |
  *********************************************/
  uint32_t *some_host_addr = (uint32_t *) (mc_tile_mmio | mc_host_y_coord | mc_host_x_coord | 0x8);
  uint32_t *tile_addr0;
  uint32_t *tile_addr1;
  uint64_t y_coord, x_coord, epa0, epa1;
  for (int i = 0; i < BSG_TOTAL_TILES; i++) {
    for(int j = 0; j < NUM_ELEMENTS; j++) {
      epa0 = (j + 2) << 2;
      epa1 = (j + 2 + NUM_ELEMENTS) << 2;
      x_coord = ((1 << HB_MC_POD_X_SUBCOORD_WIDTH) | (i % BSG_TILES_X)) << (2 + HB_MC_TILE_EPA_WIDTH);
      y_coord = ((1 << HB_MC_POD_Y_SUBCOORD_WIDTH) | (i / BSG_TILES_X)) << (2 + HB_MC_TILE_EPA_WIDTH + HB_MC_X_COORD_WIDTH);
      tile_addr0 = (uint32_t *) (mc_tile_mmio | y_coord | x_coord | epa0);
      tile_addr1 = (uint32_t *) (mc_tile_mmio | y_coord | x_coord | epa1);
      *tile_addr0 = matrix0[i][j];
      *tile_addr1 = matrix1[i][j];
    }
  }

  // Show some signs of life
  char str0[] = "BP>>Hey there! I am BlackParrot!\nBP>>Manycore, Let's do matrix-matrix add!\n";
  for(int c = 0; str0[c] != '\0'; c++) {
    *mc_stdout_addr = str0[c];
  }

  /*********************************************
   Indicate that the tiles can start computation
  *********************************************/
  for (int i = 0; i < BSG_TOTAL_TILES; i++) {
    epa0 = 0x0 << 2;
    x_coord = ((1 << HB_MC_POD_X_SUBCOORD_WIDTH) | (i % BSG_TILES_X)) << (2 + HB_MC_TILE_EPA_WIDTH);
    y_coord = ((1 << HB_MC_POD_Y_SUBCOORD_WIDTH) | (i / BSG_TILES_X)) << (2 + HB_MC_TILE_EPA_WIDTH + HB_MC_X_COORD_WIDTH);
    tile_addr0 = (uint32_t *) (mc_tile_mmio | y_coord | x_coord | epa0);
    *tile_addr0 = NUM_ELEMENTS;
  }

  /*********************************************
   Wait for an interrupt
  *********************************************/
  // Dan: Use a loop since wfi is not guaranteed
  // to break randomly
  do {
    __asm__ __volatile__ ("wfi"::);
  } while (interrupt_taken == 0);

  // Show some signs of life
  char str1[] = "BP>>I am awake!\n";
  for(int c = 0; str1[c] != '\0'; c++) {
    *mc_stdout_addr = str1[c];
  }

  /*********************************************
   Check if the manycore executed correctly
   using FIFO interface
  *********************************************/
  hb_mc_packet_t req_pkt, resp_pkt;

  req_pkt.request.op_v2 = 0;
  req_pkt.request.reg_id = 0xf;
  req_pkt.request.data = 0x0;
  req_pkt.request.x_src = (0 << HB_MC_POD_X_SUBCOORD_WIDTH) | 15;
  req_pkt.request.y_src = (1 << HB_MC_POD_Y_SUBCOORD_WIDTH) | 1;
  for (int i = 0; i < BSG_TOTAL_TILES; i++) {
    for (int j = 0; j < NUM_ELEMENTS; j++) {
      req_pkt.request.x_dst = ((1 << HB_MC_POD_X_SUBCOORD_WIDTH) | (i % BSG_TILES_X));
      req_pkt.request.y_dst = ((1 << HB_MC_POD_Y_SUBCOORD_WIDTH) | (i / BSG_TILES_X));
      req_pkt.request.addr = (j + 2 + 2*NUM_ELEMENTS) << 2;

      // Wait for credits
      while ((HB_MC_IO_MAX_EP_CREDITS - *mc_link_bp_req_credits_addr) == 0);

      // Write the packet to the manycore bridge
      for (int k = 0; k < 4; k++)
        *mc_link_bp_req_fifo_addr = req_pkt.words[k];
      
      // Wait for response
      while(*mc_link_bp_resp_entries_addr == 0);

      // Read the response
      for (int k = 0; k < 4; k++)
        resp_pkt.words[k] = *mc_link_bp_resp_fifo_addr;

      // Check for correctness
      if (matrix2[i][j] != resp_pkt.response.data) {
        *mc_fail_addr = i + j;
      }
    }
  }

  // Show some signs of life
  char str2[] = "BP>>Successfully completed matrix-matrix add!\nBP>>Bye!\n";
  for(int c = 0; str2[c] != '\0'; c++) {
    *mc_stdout_addr = str2[c];
  }

  // Terminate the simulation
  *mc_finish_addr = 0;

}