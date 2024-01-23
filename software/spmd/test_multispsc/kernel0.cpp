
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_spsc_queue.hpp"

extern "C" __attribute__ ((noinline))
void kernel0(int *send_buffer, int *send_count) {
    bsg_manycore_spsc_queue_send<int, BUFFER_ELS> send_spsc(send_buffer, send_count);

    for (int p = 0; p < NUM_PACKETS; p++) {
        int recv_data = (p << 8);
        int send_data = recv_data | (1 << 0);

        //bsg_printf("[0] RECV: %x SEND: %x\n", recv_data, send_data);
        send_spsc.send(send_data);
    }
}

