// This file defines N number of mostly identical kernels (up to 16 currently)
// These kernels will
// - print hello from a tile
// - process an input buffer of size N by adding 100*its kernel id
// - sync using a global AMOADD, waiting for all K kernels to reach

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_atomic.h"

#define K NUM_KERNELS
#define N BUFFER_SIZE

// Declaring kernels as extern
extern "C" int kernel0(int *buffer, int n, int *sync, int k);
extern "C" int kernel1(int *buffer, int n, int *sync, int k);
extern "C" int kernel2(int *buffer, int n, int *sync, int k);
extern "C" int kernel3(int *buffer, int n, int *sync, int k);
extern "C" int kernel4(int *buffer, int n, int *sync, int k);
extern "C" int kernel5(int *buffer, int n, int *sync, int k);
extern "C" int kernel6(int *buffer, int n, int *sync, int k);
extern "C" int kernel7(int *buffer, int n, int *sync, int k);

// Some global variables needed for the kernels
int buffer[K*N] __attribute__ ((section (".dram")));
int sync __attribute__ ((section (".dram"))) = 0;

// Some global variables needed for amoadd barrier
extern "C" void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;

// Preamble, setup only done by core 0
void preamble() {
    for (int j = 0; j < K; j++) {
        for (int i = 0; i < N; i++) { /* fill A with increasing data */
            buffer[j*N+i] = i;
            bsg_printf("Host Buffer Initial[%d]: %d\n", j*N+i, i);
        }
    }
}

// Postamble, cleanup only done by core 0
void postamble() {
    for (int j = 0; j < K; j++) {
        for (int i = 0; i < N; i++) {
            bsg_printf("Host Buffer Final[%d]: %d\n", j*N+i, buffer[j*N+i]);
            if (buffer[j*N+i] != (j+1)*100+i) {
                bsg_printf("MISMATCH: %d != %d\n", buffer[j*N+i], (j+1)*100+i);
                bsg_fail();
            }
        }
    }
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
  // (must synchronize before and after)
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm); 
  switch (__bsg_id) {
    case 0: kernel0(buffer, N, &sync, K); break;
    case 1: kernel1(buffer, N, &sync, K); break;
    case 2: kernel2(buffer, N, &sync, K); break;
    case 3: kernel3(buffer, N, &sync, K); break;
    case 4: kernel4(buffer, N, &sync, K); break;
    case 5: kernel5(buffer, N, &sync, K); break;
    case 6: kernel6(buffer, N, &sync, K); break;
    case 7: kernel7(buffer, N, &sync, K); break;
  }
  bsg_barrier_amoadd(&amoadd_lock, &amoadd_alarm); 

  // Do some cleanup if necessary 
  if (__bsg_id == 0) {
    postamble();
  }

  // Spin
  bsg_wait_while(1);
}

