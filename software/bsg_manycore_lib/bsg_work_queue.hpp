#pragma once
#include <atomic>
#include "bsg_manycore.hpp"
#include "bsg_manycore.h"
#include "bsg_mcs_mutex.h"

template <typename T>
static T atomic_load(volatile T *v)
{
    return *v;
}

struct Job {
    typedef void (*Function)(int,int,int,int,int,int);
    static constexpr int MAX_ARGS = 6;
    Job*      next;
    //int   argc;
    Function  func;
    int       argv [MAX_ARGS];
};

/**
 * Must live in DRAM
 */
struct JobQueue {
    std::atomic<Job*> ready_tail;
    Job **            ready_head;
    /**
     * Enqueue a job
     */
    void enqueue(Job *j) {        
        Job *old_tail = this->ready_tail.exchange(j, std::memory_order_relaxed);
        Job **rh = this->ready_head;
        bsg_compiler_memory_barrier();
        if (old_tail == nullptr) {
            *rh = j;
        } else {
            old_tail->next = j;
        }
    }

    /**
     * Enqueue a list of jobs
     */
    void enqueue_jobl(Job *h, Job *t) {
        Job *old_tail = this->ready_tail.exchange(t, std::memory_order_relaxed);
        Job **rh = this->ready_head;
        bsg_compiler_memory_barrier();
        if (old_tail == nullptr) {
            *rh = h;
        } else {
            old_tail->next = h;
        }
    }
    /**
     * Enqueue a vector of jobs
     */
    void enqueue_jobv(Job *begin, Job *end) {
        int n = end-begin;
        int i = 0;
        // vectorize
        for (; i + 8 < n-1; i += 8) {
            bsg_unroll(8)
            for (int j = 0; j < 8; j++) {
                begin[i+j].next = &begin[i+j+1];
            }
        }
        // strip mine
        for (; i < n-1; i++) {
            begin[i].next = &begin[i+1];
        }
        begin[n-1].next = nullptr;
        enqueue_jobl(&begin[0], &begin[n-1]);
    }
};


/**
 * Must live in DMEM
 */
struct Worker {    
    Job   *ready_head;
    Job   *pending_head;
    Job   *pending_tail;
    Job    job;
    JobQueue *queue;
    void init(JobQueue *q) {
        this->queue = q;
        Worker *self = bsg_tile_group_remote_pointer<Worker>(__bsg_x, __bsg_y, this);
        this->queue->ready_head = &(self->ready_head);
        this->pending_head = nullptr;
        this->pending_tail = nullptr;        
        this->ready_head = nullptr;        
    }

    void loop() {        
        while (true) {
            // any pending jobs?
            if (this->pending_head == nullptr) {
                // wait for a ready job
                while (atomic_load(&this->ready_head) == nullptr);
                // move ready jobs to pending
                this->pending_head = this->ready_head;
                this->ready_head = nullptr;
                // amoswap ready_tail with null, save as tail of pending queue
                // this will 'unlock' ready_head, after which the next enqueue job will update
                this->pending_tail = this->queue->ready_tail.exchange(nullptr, std::memory_order_relaxed);
            }
            // load entire job
            this->job = *(this->pending_head);
            // address race condition where there is ready job added to pending queue,
            // but pending head not updated yet
            // hopefully this very rare
            if (this->job.next == nullptr && this->pending_head != this->pending_tail) {
                do {
                    this->job.next = atomic_load(&this->pending_head->next);
                } while (this->job.next == nullptr);
            }

            // update the head
            this->pending_head = this->job.next;

            // execute job
            Job::Function f = reinterpret_cast<Job::Function>(this->job.func);
            f(this->job.argv[0]
              ,this->job.argv[1]
              ,this->job.argv[2]
              ,this->job.argv[3]
              ,this->job.argv[4]
              ,this->job.argv[5]);
        }
    }
};

