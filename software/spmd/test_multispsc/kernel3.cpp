
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_spsc_queue.hpp"

extern "C" __attribute__ ((noinline))
void kernel3(int *recv_buffer, int *recv_count, int *send_buffer, int *send_count) {
    bsg_manycore_spsc_queue_recv<int, BUFFER_ELS> recv_spsc(recv_buffer, recv_count);
    bsg_manycore_spsc_queue_send<int, BUFFER_ELS> send_spsc(send_buffer, send_count);

    while (1) {
        int recv_data = recv_spsc.recv();
        int send_data = recv_data | (1 << 3);
        //bsg_printf("[3] RECV: %x SEND: %x\n", recv_data, send_data);

        send_spsc.send(send_data);
    }
}

