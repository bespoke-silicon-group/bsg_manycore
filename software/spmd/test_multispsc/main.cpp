// This file defines N number of mostly identical kernels (up to 16 currently)
// These kernels will
// - print hello from a tile
// - process an input buffer of size N by adding 100*its kernel id
// - sync using a global AMOADD, waiting for all K kernels to reach

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"

// Declaring kernels as extern
extern "C" int kernel0(int *send_buffer, int *send_count);
extern "C" int kernel1(int *send_buffer, int *send_count, int *recv_buffer, int *recv_count);
extern "C" int kernel2(int *send_buffer, int *send_count, int *recv_buffer, int *recv_count);
extern "C" int kernel3(int *send_buffer, int *send_count, int *recv_buffer, int *recv_count);
extern "C" int kernel4(int *send_buffer, int *send_count, int *recv_buffer, int *recv_count);
extern "C" int kernel5(int *send_buffer, int *send_count, int *recv_buffer, int *recv_count);
extern "C" int kernel6(int *send_buffer, int *send_count, int *recv_buffer, int *recv_count);
extern "C" int kernel7(int *recv_buffer, int *recv_count);

// Some global variables needed for the kernels
int buffer_chain [CHAIN_LEN*BUFFER_ELS] __attribute__ ((section (".dram"))) = {0};
int buffer_count [CHAIN_LEN] __attribute__ ((section (".dram"))) = {0};

// Some global variables needed for amoadd barrier
extern "C" void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;

// Preamble, setup only done by core 0
void preamble() {
   bsg_printf("Core%d preamble...\n", __bsg_id);
}

// Postamble, cleanup only done by core 7
void postamble() {
  bsg_printf("Core%d postamble...\n", __bsg_id);
  bsg_finish();
}

int main()
{
  /************************************************************************
   This will setup the  X/Y coordination. Current pre-defined corrdinations
   includes:
        __bsg_x         : The X cord inside the group
        __bsg_y         : The Y cord inside the group
        __bsg_org_x     : The origin X cord of the group
        __bsg_org_y     : The origin Y cord of the group
  *************************************************************************/
  bsg_set_tile_x_y();
  bsg_fence();

  // Do some setup from your "host" tile
  if (__bsg_id == 0) {
    preamble();
  }

  // Launch to individual kernels
  // (must synchronize before)
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm); 
  switch (__bsg_id) {
    case 0: kernel0(
                    &buffer_chain[1*BUFFER_ELS], &buffer_count[1]); break;
    case 1: kernel1(&buffer_chain[1*BUFFER_ELS], &buffer_count[1],
                    &buffer_chain[2*BUFFER_ELS], &buffer_count[2]); break;
    case 2: kernel2(&buffer_chain[2*BUFFER_ELS], &buffer_count[2],
                    &buffer_chain[3*BUFFER_ELS], &buffer_count[3]); break;
    case 3: kernel3(&buffer_chain[3*BUFFER_ELS], &buffer_count[3],
                    &buffer_chain[4*BUFFER_ELS], &buffer_count[4]); break;
    case 4: kernel4(&buffer_chain[4*BUFFER_ELS], &buffer_count[4],
                    &buffer_chain[5*BUFFER_ELS], &buffer_count[5]); break;
    case 5: kernel5(&buffer_chain[5*BUFFER_ELS], &buffer_count[5],
                    &buffer_chain[6*BUFFER_ELS], &buffer_count[6]); break;
    case 6: kernel6(&buffer_chain[6*BUFFER_ELS], &buffer_count[6],
                    &buffer_chain[7*BUFFER_ELS], &buffer_count[7]); break;
    case 7: kernel7(&buffer_chain[7*BUFFER_ELS], &buffer_count[7]
                                                                 ); break;
                    
  }

  // Do some cleanup if necessary 
  if (__bsg_id == 7) {
    postamble();
  }

  // Spin
  bsg_wait_while(1);
}

