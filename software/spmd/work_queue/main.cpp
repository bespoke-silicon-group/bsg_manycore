#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_work_queue.hpp"
#include "bsg_mcs_mutex.h"

__attribute__((section(".dram")))
int b_l = 0;
int b_s = 1;
extern "C" void bsg_barrier_amoadd(int *l, int *s);

struct QueueW {
    struct JobQueue q;
    char padding [VCACHE_BLOCK_SIZE_WORDS*4-sizeof(JobQueue)];
};

__attribute__((section(".dram"), aligned(VCACHE_BLOCK_SIZE_WORDS*4 * bsg_tiles_X * 2)))
QueueW queue [bsg_tiles_X * bsg_tiles_Y];

int q_select;

__attribute__((section(".dram")))
Job jobs[bsg_tiles_X * bsg_tiles_Y];

static void job_first();
static void say_hi()
{
    bsg_print_int(__bsg_id);
    if (__bsg_id == 0)
        bsg_finish();
    
    Job *j = &jobs[__bsg_id];
    j->func = (Job::Function)say_hi;
    JobQueue *q = &queue[(q_select+1)%(bsg_tiles_X*bsg_tiles_Y)].q;
    q->enqueue(j);
}        

static void start()
{
    Job *j = &jobs[__bsg_id];
    j->func = (Job::Function)say_hi;
    JobQueue *q = &queue[(q_select+1)%(bsg_tiles_X*bsg_tiles_Y)].q;
    q->enqueue(j);
}

//#define DEBUG
int main()
{    
    bsg_set_tile_x_y();
    Worker w;
    int south_not_north = __bsg_y/(bsg_tiles_Y/2);
    int grp_y = (__bsg_y % (bsg_tiles_Y/2));
    q_select = (grp_y << 5) | (south_not_north << 4) |__bsg_x;
    //q_select = __bsg_id;
    w.init(&queue[q_select].q);
    bsg_barrier_amoadd(&b_l, &b_s);
    /*
     * Enqueue first job onto your work queue
     */
    if (__bsg_x == bsg_tiles_X/2 &&
        __bsg_y == bsg_tiles_Y/2) {
        Job *j = &jobs[__bsg_id];
        JobQueue *q = &queue[q_select].q;
        j->func = (Job::Function)start;
        q->enqueue(j);        
    }
    w.loop();
}
