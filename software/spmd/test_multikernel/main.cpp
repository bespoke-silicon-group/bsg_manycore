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

#define MAKE_KERNEL_DEF(x) kernel##x
#define KERNEL_DEF(x) \
  extern "C" __attribute__ ((noinline))                                               \
  int MAKE_KERNEL_DEF(x)(int *buffer, int n, int *sync, int k) {                      \
  bsg_printf("Hello from kernel %d -- Tile X: %d Tile Y: %d\n", x, __bsg_x, __bsg_y); \
                                                                                      \
  for (int i = 0; i < n; i++) {                                                       \
      buffer[x*n+i] += 100*(x+1);                                                     \
      bsg_printf("kernel %d Process[%d]: %d\n", x, i, buffer[x*n+i]);                 \
  }                                                                                   \
                                                                                      \
  volatile int *sync_ptr = sync;                                                      \
  int sync_val;                                                                       \
  bsg_printf("[kernel %d] Trying to sync to EVA: %x", x, sync);                       \
  bsg_amoadd(sync, 1);                                                                \
  while ((sync_val = *sync_ptr) < k) {                                                \
     bsg_printf("[kernel %d] Waiting for sync_ptr == %d (%d)", x, k, sync_val);       \
  }                                                                                   \
                                                                                      \
  return 0;                                                                           \
}

extern "C" void bsg_barrier_amoadd(int*, int*);
int amoadd_lock __attribute__ ((section (".dram"))) = 0;
int amoadd_alarm = 1;

int buffer[K*N] __attribute__ ((section (".dram")));
int sync __attribute__ ((section (".dram"))) = 0;

KERNEL_DEF(0)
KERNEL_DEF(1)
KERNEL_DEF(2)
KERNEL_DEF(3)
KERNEL_DEF(4)
KERNEL_DEF(5)
KERNEL_DEF(6)
KERNEL_DEF(7)

void preamble() {
    for (int j = 0; j < K; j++) {
        for (int i = 0; i < N; i++) { /* fill A with increasing data */
            buffer[j*N+i] = i;
            bsg_printf("Host Buffer Initial[%d]: %d\n", j*N+i, i);
        }
    }
}

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

  // Do some setup
  if (__bsg_id == 0) {
    preamble();
  }

  // Jump to the actual kernels
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

  // Do some cleanup  
  if (__bsg_id == 0) {
    postamble();
  }

  // Spin
  bsg_wait_while(1);
}

