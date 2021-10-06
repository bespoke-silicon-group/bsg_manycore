#pragma once
#include <atomic>
#include "bsg_mcs_mutex.h"

struct sync {
    int done;
};

struct task {
    task *next;
    void (*func)();
    sync sync;
};

struct task_queue {
    std::atomic<task*> head; // one worker can pop
    std::atomic<task*> tail; // anyone can push
}

struct worker {
    worker *next_idle; // pointer to next idle worker
    worker *self; // globally addressable pointer to self
    task   *task; // set to next task to perform
};

struct worker_queue {
    std::atomic<worker*> head; // one can pop
    std::atomic<worker*> tail; // anyone can push
};

