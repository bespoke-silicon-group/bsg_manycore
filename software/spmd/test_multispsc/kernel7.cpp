
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_spsc_queue.hpp"

extern "C" __attribute__ ((noinline))
void kernel7(int *recv_buffer, int *recv_count) {
  bsg_manycore_spsc_queue_recv<int, BUFFER_ELS> recv_spsc(recv_buffer, recv_count);

  for (int p = 0; p < NUM_PACKETS; p++) {
    int recv_data = recv_spsc.recv();
    int send_data = recv_data | (1 << 7);
    //bsg_printf("[7] RECV: %x SEND: %x\n", recv_data, send_data);

    int actual = send_data;
    int expected = (p << 8) | 0xff;
    if (actual != expected) {
      bsg_printf("[mismatch] actual: %x expected: %x\n", actual, expected);
      bsg_fail();
    } else {
      bsg_printf("[match] actual: %x expected: %x\n", actual, expected);
    }
  }
}

