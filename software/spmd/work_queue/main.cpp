#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_work_queue.hpp"

__attribute__((section(".dram")))
task_queue task;

__attribute__((section(".dram")))
worker_queue workers;
worker worker;

int main()
{

  bsg_set_tile_x_y();

  if (__bsg_id != 0)
      worker_wait(&workers, &worker);
  
  if (__bsg_x == 0 && __bsg_y == 0)
      bsg_finish();
  
  bsg_wait_while(1);
}
