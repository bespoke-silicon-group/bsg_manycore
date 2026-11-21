//This kernel performs a barrier among all tiles in tile group 

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_manycore_spsc_queue.hpp"
#include "bsg_tile_group_barrier.hpp"

bsg_barrier<bsg_tiles_X, bsg_tiles_Y> barrier;

#define BUFFER_ELS 24
#define CHAIN_LEN   8
#define NUM_PACKETS 1000

int buffer_chain [CHAIN_LEN*BUFFER_ELS] __attribute__ ((section (".dram"))) = {0};
int buffer_count [CHAIN_LEN] __attribute__ ((section (".dram"))) = {0};

int main()
{
    bsg_set_tile_x_y();

    int *buffer = &buffer_chain[0] + (__bsg_id * BUFFER_ELS);
    int *count  = &buffer_count[0] + (__bsg_id);

    int *next_buffer = &buffer_chain[0] + ((__bsg_id+1) * BUFFER_ELS);
    int *next_count = &buffer_count[0] + (__bsg_id+1);

    bsg_manycore_spsc_queue_recv<int, BUFFER_ELS> recv_spsc(buffer, count);
    bsg_manycore_spsc_queue_send<int, BUFFER_ELS> send_spsc(next_buffer, next_count);

    int packets = 0;
    int recv_data;
    int send_data;
    do
    {
        if (__bsg_id == 0)
        {
            recv_data = packets;
        }
        else
        {
            recv_data = recv_spsc.recv();
        }

        //bsg_printf("[%d] RECV %d\n", __bsg_id, recv_data);

        send_data = recv_data;

        if (__bsg_id == CHAIN_LEN-1)
        {
            if (recv_data != packets)
            {
                bsg_fail();
            }
        }
        else
        {
            send_spsc.send(send_data);
        }

        //bsg_printf("[%d] SEND %d\n", __bsg_id, send_data);
    } while (++packets < NUM_PACKETS);

    barrier.sync();
    bsg_finish();
    bsg_wait_while(1);
	return 0;
}

