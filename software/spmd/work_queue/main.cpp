#include "bsg_manycore.h"
#include "bsg_set_tile_x_y.h"
#include "bsg_work_queue.hpp"
#include "bsg_mcs_mutex.h"
#include "bsg_malloc_amoadd.h"
#include "string.h"

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

#define JOBS 1024

static void finish(int x)
{
    static int count = 0;
    count += x;
    bsg_print_int(count);
    if (count == JOBS)
        bsg_finish();
}

static void update()
{
    static int count = 0;
    count++;
    bsg_print_int(count);
    if (count == JOBS/(bsg_tiles_X*bsg_tiles_Y)) {
        Job *j = (Job*)bsg_malloc_amoadd(sizeof(Job));
        memset(j, 0, sizeof(*j));
        j->func = (Job::Function)finish;
        j->argv[0] = count;
        JobQueue *q = &queue[bsg_x_y_to_id(bsg_tiles_X/2,bsg_tiles_Y/2)].q;
        q->enqueue(j);
    }
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

        Job *jobs = (Job*)bsg_malloc_amoadd(sizeof(Job) * JOBS);
        memset(jobs,0,sizeof(Job) * JOBS);

        int n = JOBS/(bsg_tiles_X*bsg_tiles_Y);
        for (int i = 0; i < JOBS; i++) {
            jobs[i].func = (Job::Function)update;
        }

        for (int t = 0; t < bsg_tiles_X*bsg_tiles_Y; t++) {
            JobQueue *q = &queue[t].q;
            Job *j = &jobs[t*n];
            q->enqueue_jobv(j,j+n);            
        }
    }
    w.loop();
}
