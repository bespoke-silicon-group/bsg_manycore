#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_work_queue.hpp"
#include "bsg_mcs_mutex.h"

#define JOBS 100

__attribute__((section(".dram")))
int b_l = 0;
int b_s = 1;
extern "C" void bsg_barrier_amoadd(int *l, int *s);


__attribute__((section(".dram")))
task_queue workq;

__attribute__((section(".dram")))
bsg_mcs_mutex_t lock;
bsg_mcs_mutex_node_t  node;
bsg_mcs_mutex_node_t *self;
void say_hi(task *t)
{
    bsg_print_int(t->data[0]);
}

//#define DEBUG
int main()
{

  bsg_set_tile_x_y();

  self = bsg_tile_group_remote_pointer<bsg_mcs_mutex_node_t>(__bsg_x, __bsg_y, &node);

  manager m;
  if (__bsg_x == bsg_tiles_X/2
      && __bsg_y == bsg_tiles_Y/2)
      manager_init(&m, &workq);

  bsg_barrier_amoadd(&b_l, &b_s);
  
  if (__bsg_x == bsg_tiles_X/2
      && __bsg_y == bsg_tiles_Y/2) {
      // jobs
      task job  [JOBS];
      int  _sync [JOBS] = {};
      int *sync = bsg_tile_group_remote_pointer(__bsg_x, __bsg_y, _sync);

      // enqueue jobs
      for (int i = 0; i < JOBS; i++) {
          task_clear(&job[i]);
          job[i].call = say_hi;
          job[i].done = &sync[i];
          job[i].data[0] = i;
          job[i].data_words = 1;
          manager_enqueue(&m, &job[i]);
      }

      // dispatch all jobs
      for (int i = 0; i < JOBS; i++) {
          manager_dispatch(&m);
      }

      // wait for jobs to complete
      for (int i = 0; i < JOBS; i++) {
          int *sp = bsg_tile_group_remote_pointer(__bsg_x, __bsg_y, &_sync[i]);
          while (atomic_load(sp) != 1);
      }
      bsg_finish();
  } else {
      worker w;
      worker_init(&w, &workq);
  }
  
  bsg_wait_while(1);
}
