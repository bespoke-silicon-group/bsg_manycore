
#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_token_queue.h"

bsg_declare_token_queue(tq);

int sep[4];

#define kTransmitSize 100
#define kBufferWindows 2
#define kBufferSize (kTransmitSize*kBufferWindows)
#define kBlocks 100

int buffer[kBufferSize+10];

int source_process(int *ptr)
{
  for (int j = 0; j < kTransmitSize; j++)
    ptr[j] = j;
}

int dest_process(int sum, int *ptr, volatile int *io_ptr)
{
  for (int i = 0; i < kTransmitSize; i++)
    sum += *ptr++;

  *io_ptr = sum;

  return sum;
}



int main()
{
  bsg_set_tile_x_y();

  int id = bsg_x_y_to_id(bsg_x,bsg_y);
  int *ptr = bsg_remote_ptr(1,0,buffer);
  int bufIndex = 0;

  bsg_print_time();

  if (id == 0)
  {
    int seq = 0;
    bsg_print_time();
    for (int i = 0; i < kBlocks; i++)
    {
      // ensure that there are 5 elements free
      bsg_tq_sender_confirm(tq,1,0,kBufferSize,kTransmitSize);

      source_process(&ptr[bufIndex]);

      bufIndex += kTransmitSize;
      if (bufIndex == kBufferSize)
        bufIndex = 0;

      bsg_tq_sender_xfer(tq,1,0,kBufferSize,kTransmitSize);
    }
    bsg_wait_while(1);
  }
  else if (id == 1)
  {
    int sum=0;
    bsg_remote_int_ptr io_ptr = bsg_remote_ptr_io(0,0xCAB0);
    for (int i = 0; i < kBlocks; i++)
    {

      int * ptr = buffer;

      // ensure that there are 3 elements available
      bsg_tq_receiver_confirm(tq,0,0,kTransmitSize);

      sum = dest_process(sum,&ptr[bufIndex],io_ptr);

      bufIndex += kTransmitSize;

      if (bufIndex == kBufferSize)
      {
        bufIndex = 0;
        ptr = buffer ;
      }

      bsg_tq_receiver_release(tq,0,0,kTransmitSize);
    }
    bsg_finish();
  }

  bsg_wait_while(1);
}

