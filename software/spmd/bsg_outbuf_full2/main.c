#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"

#define N 8

volatile int valid = 0;
int buf0[N] = {0};
int buf1[N] = {0};

void proc (int id)
{
  // wait while valid becomes one
  while (1)
  {
    if (valid == 1) break;
  }
  bsg_heartbeat_iter(id);
  // Replaced to reduce simulation runtime and remove printf from binary
  // bsg_printf("I am awake. id=%d\n", id);

  // copy from buf0 to buf1
  for (int i = 0; i < N; i++)
  {
    buf1[i] = buf0[i];
  }

  // the last tile validates and sends finish.
  // the other tiles copy to the next tile and set valid.
  if (id == (bsg_tiles_X*bsg_tiles_Y)-1)
  {
    for (int i = 0; i < N; i++)
    {
      if (buf1[i] != i+1) bsg_fail();
    }
    bsg_finish();
  }
  else
  {
    int next_x = bsg_id_to_x(id+1);
    int next_y = bsg_id_to_y(id+1);
    
    for (int i = 0; i< N; i++)
    {
      bsg_remote_store(next_x, next_y, &buf0[i], buf1[i]);
    }  
    bsg_remote_store(next_x,next_y, &valid, 1);
  }

  bsg_wait_while(1);
}

void main()
{

  bsg_set_tile_x_y();
  
  int id  = bsg_x_y_to_id(__bsg_x,__bsg_y);

  // id=0 initialize data
  if (id == 0)
  {
    for (int i = 0; i < N; i++)
    {
      buf0[i] = i+1;
    }
    valid = 1;
  }

  proc(id);

}
