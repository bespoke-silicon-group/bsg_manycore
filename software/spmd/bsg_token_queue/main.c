#define kBufferWindows 2
#define kTransmitSize 100
#define kBufferSize (kTransmitSize*kBufferWindows)
#define kBlocks 100

//////////////////////////////////////////////////////////////////
//if this is the program running under Rocket control, we need a data structure 
//to communicate with Rocket
#ifdef ROCKET_MANYCORE

#define MANYCORE_PROG
#define MANYCORE_DST_BUF_LEN        kBlocks
#include "bsg_manycore_buffer.h"

#endif
//////////////////////////////////////////////////////////////////

int buffer[kBufferSize+10];

int source_process(int *ptr)
{
  for (int j = 0; j < kTransmitSize; j+=2)
  {
    ptr[j]   = j;
    ptr[j+1] = j;
  }
}

int dest_process(int sum, int *ptr, volatile int *io_ptr)
{
  for (int i = 0; i < kTransmitSize; i++)
    sum += *ptr++;

  *io_ptr = sum;

  return sum;
}

#ifdef VERIFY

#include <stdlib.h>
#include <stdio.h>

int main()
{
  int sum;
  int io_ptr;
  for (int i = 0; i < kBlocks; i++)
  {
    source_process(buffer);
    sum=dest_process(sum,buffer,&io_ptr);
    printf("%x\n",io_ptr);
  }
}

#else

#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_token_queue.h"

bsg_declare_token_queue(tq);


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
    bsg_token_connection_t conn = bsg_tq_send_connection(tq,1,0);

    for (int i = 0; i < kBlocks; i++)
    {
      // ensure that at least a frame is available to write
      // we could have also counted in terms of kTransmitSize word buffers
      // with input parameters of kBufferWindows,1
      bsg_tq_sender_confirm(conn,kBufferWindows,1);

      source_process(&ptr[bufIndex]);

      bsg_tq_sender_xfer(conn,kBufferWindows,1);

      bufIndex+=kTransmitSize;
      if (bufIndex == kBufferSize)
        bufIndex = 0;
    }
    bsg_wait_while(1);
  }
  else if (id == 1)
  {
    int sum=0;
    bsg_token_connection_t conn = bsg_tq_receive_connection(tq,0,0);
    bsg_remote_int_ptr io_ptr ;
    for (int i = 0; i < kBlocks; i++)
    {

      int * ptr = buffer;

      // ensure that at least a frame is available to write
      // we could have also counted in terms of kTransmitSize word buffers
      // with input parameters of kBufferWindows,1

      bsg_tq_receiver_confirm(conn,1);

      #ifdef ROCKET_MANYCORE
      io_ptr = bsg_remote_ptr_io(0,(( unsigned int )manycore_data_s.result  \
                                        + manycore_data_s.base_addr         \
                                        + i*4                               \
                                   )                                        \
                                 );
      #else
      io_ptr = bsg_remote_ptr_io(0,0xCAB0);
      #endif

      sum = dest_process(sum,&ptr[bufIndex],io_ptr);

      bsg_tq_receiver_release(conn,1);

      bufIndex += kTransmitSize;

      if (bufIndex == kBufferSize)
      {
        bufIndex = 0;
        ptr = buffer ;
      }
    }
    #ifdef ROCKET_MANYCORE
        bsg_rocc_finish(& manycore_data_s);        
    #else
        bsg_finish();
    #endif
  }

  bsg_wait_while(1);
}
////////////////////////////////////////////////////////////////
//Print the current manycore configurations
#pragma message (bsg_VAR_NAME_VALUE( bsg_tiles_X )  )
#pragma message (bsg_VAR_NAME_VALUE( bsg_tiles_Y )  )
#pragma message (bsg_VAR_NAME_VALUE( kTransmitSize )  )
#pragma message (bsg_VAR_NAME_VALUE( kBlocks )  )
#pragma message (bsg_VAR_NAME_VALUE( kBufferSize )  )

#endif
