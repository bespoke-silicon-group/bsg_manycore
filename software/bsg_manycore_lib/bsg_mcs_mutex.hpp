// MCS mutex
// Author: Max
//
// This is an implementation of the MCS mutex inspired in part by Mellor-Crummey and Scott in their 1991 paper
// “Algorithms for Scalable Synchronization on Shared-Memory Multiprocessors”
//
// This is a spinlock mutex, but unlike a simple spinlock in which all threads update and spin on
// a single memory location, the MCS lock builds a linked-list of memory locations local to each core.
//
// Cores atomically append their local memory region to the global list using an unconditional
// amoswap operation. They then spin on their local memories for a predecessor in the queue
// to notify them that they now hold the lock.
//
// Once a core has completed its critical region, it checks for a successor and updates releases the lock to them.
//
// The advantages of this mutex over a simple spin lock on the manycore are two fold:
//
// (1) It greatly reduces the number of memory requests on the network and it mitigates the extent to which
// a single memory bank becomes a hot-spot. The number of requests issued to a memory bank containing the
// lock object is linear with the number of times an acquire operation is executed.
//
// (2) The lock approximates a FIFO-ish structure, which improves fairness. A simple spinlock on the manycore
// will favor threads topologically closer to the memory bank in which the lock resides and can lead to
// starvation of the other cores.
//
// This lock is by no means perfect. For locks with low contention, a simple spinlock may result in better performance.

#pragma once
#include <atomic>
#include "bsg_manycore.h"
#include "bsg_tile_config_vars.h"
#include "bsg_tile_group_barrier.h"

template <typename T>
static T atomic_load(volatile T *ptr) {
    return *ptr;
}

// Must live in tile's local memory (DMEM)
// Do not reorder the members in this struct
// The assembly code in bsg_mcs_mutex.S depends on this ordering.
typedef struct bsg_mcs_mutex_node {
    int                  unlocked;
    struct bsg_mcs_mutex_node* next;
} bsg_mcs_mutex_node_t;

/**
 * This object must live in global memory (DRAM).
 */
typedef std::atomic<bsg_mcs_mutex_node*> bsg_mcs_mutex_t;

/**
 * Acquire the mutex, returns when the lock has been acquired.
 * @param mtx         A pointer to a MCS mutex (must be in DRAM)
 * @param lcl         A local pointer to a node allocated in tile's local memory
 * @param lcl_as_glbl A global pointer to the same location as lcl
 *
 * lcl_as_glbl must point to the same memory as lcl and it must be addressable by other cores
 * with whom the mutex is to be shared.
 *
 * The most common use case would be a mutex for sharing within a tile group, in which case a
 * tile group shared pointer should be used (see bsg_tile_group_remote_ptr).
 *
 * However, lcl_as_glbl can also be a global pointer to support sharing across tile groups (see bsg_global_pod_ptr).
 *
 * Pointer casting macros can be found in bsg_manycore_arch.h
 */
static void bsg_mcs_mutex_acquire(bsg_mcs_mutex_t *mtx
                                  , bsg_mcs_mutex_node_t *lcl
                                  , bsg_mcs_mutex_node_t *lcl_as_glbl)
{
    bsg_mcs_mutex_node_t *pred; // who's before us

    lcl->next = nullptr;
    lcl->unlocked = 0;

    pred = mtx->exchange(lcl_as_glbl, std::memory_order_acquire);
    // was there someone before us in line?
    if (pred != nullptr) {
        // tell our predecessor to notify us when done
        pred->next = lcl_as_glbl;
        // wait on our locked variable
        bsg_wait_local_int_asm(&lcl->unlocked, 1);
    }
}

/**
 * Release the mutex, returns when the lock has been released and the calling core no longer holds the lock.
 * @param mtx         A pointer to a MCS mutex (must be in DRAM)
 * @param lcl         A local pointer to a node allocated in tile's local memory
 * @param lcl_as_glbl A global pointer to the same location as lcl
 *
 * lcl_as_glbl must point to the same memory as lcl and it must be addressable by other cores
 * with whom the mutex is to be shared.
 *
 * The most common use case would be a mutex for sharing within a tile group, in which case a
 * tile group shared pointer should be used (see bsg_tile_group_remote_ptr).
 *
 * However, lcl_as_glbl can also be a global pointer to support sharing across tile groups (see bsg_global_pod_ptr).
 *
 * Pointer casting macros can be found in bsg_manycore_arch.h
 */
static void bsg_mcs_mutex_release(bsg_mcs_mutex_t *mtx
                                  , bsg_mcs_mutex_node_t *lcl
                                  , bsg_mcs_mutex_node_t *lcl_as_glbl)
{
    // successor exists, unlock and return
    if (lcl->next != nullptr) {
        // fence and release
        bsg_fence();
        lcl->next->unlocked = 1;
        return;
    }

    // no successor, head still points to us
    // attempt to swap out head with null
    bsg_mcs_mutex_node_t *vic_tail;
    vic_tail = mtx->exchange(nullptr, std::memory_order_release);
    if (vic_tail == lcl_as_glbl) {
        // there's still no successor
        return;
    }

    // a successor added itself to the queue
    // we have to put it back
    bsg_mcs_mutex_node_t *usurper;
    usurper = mtx->exchange(vic_tail, std::memory_order_release);

    // wait for next pointer to point to some head of our victims
    while (atomic_load(&lcl->next) == nullptr);

    // did someone else get in line in the mean time?
    if (usurper == nullptr) {
        lcl->next->unlocked = 1;
        return;
    }

    // add victims behind usurper
    usurper->next = lcl->next;
}
