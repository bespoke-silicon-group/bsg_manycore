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

        .text
        .globl bsg_mcs_mutex_acquire
        // Refer to bsg_mcs_mutex.h for detailed description of usage.
        // a0 = mtx         : bsg_mcs_mutex_t*, points to DRAM
        // a1 = lcl         : bsg_mcs_mutex_node_t*, local pointer that points to DMEM
        // a2 = lcl_as_glbl : bsg_mcs_mutex_node_t*, global pointer to same location as 'lcl'
bsg_mcs_mutex_acquire:
        sw      x0, 4(a1)                      // lcl->next = 0
        sw      x0, 0(a1)                      // lcl->unlocked = 0
        amoswap.w.aq t0, a2, 0(a0)             // predecessor = swap (&mtx, lcl_as_glbl)
        beqz    t0, bsg_mcs_mutex_acquire_ret  // return if predecessor = 0
        sw      a2, 4(t0)                      // predecessor->next = lcl_as_glbl
bsg_mcs_mutex_acquire_loop:
        // Here we use the load-on-broken-reservation semantics to avoid
        // busy waiting. This reduces the dynamic energy of the core
        // and removes contention on our local memory from updates by
        // other cores, including an update from our predecessor
        // for when they release the lock to us.
        //
        // The expected wait time for this load is arbitrarily long as it depends
        // on (1) the time it takes client code to complete the critical region
        // and (2) the contention on this lock.
        // We expect the wait time to be on the order of 20-100 cycles in the
        // case where there is low contention on the lock.
        lr.w    t0, (a1)                       // unlocked = lcl->unlocked
        bnez    t0, bsg_mcs_mutex_acquire_ret  // return if unlocked
        lr.w.aq t0, (a1)                       // unlocked = lcl->unlocked
        // MBT: backwards predict not taken branch variant would be helpful here
        beqz    t0, bsg_mcs_mutex_acquire_loop // while !unlocked
bsg_mcs_mutex_acquire_ret:
        ret

        .globl bsg_mcs_mutex_release
        // Refer to bsg_mcs_mutex.h for detailed description of usage.
        // a0 = mtx         : bsg_mcs_mutex_t*, points to DRAM
        // a1 = lcl         : bsg_mcs_mutex_node_t*, local pointer that points to DMEM
        // a2 = lcl_as_glbl : bsg_mcs_mutex_node_t*, global pointer to same location as 'lcl'        
bsg_mcs_mutex_release:
        lw      t0, 4(a1)                                   // next = lcl->next
        li      t1, 1                                       // t1 = 1
        beqz    t0, bsg_mcs_mutex_release_no_successor      // branch if no successor
        // this is the case where there is a successor
        // we need only unlock the successor and return
        fence                                               // fence to implement release semantics
        sw      t1, 0(t0)                                   // successor->unlocked = 1
        ret
bsg_mcs_mutex_release_no_successor:
        // this is the case where there is no known successor
        // attempt to swap out the tail pointer with 0
        amoswap.w.rl t2, x0, 0(a0)                          // victim_tail = swap(&mtx, 0)
        bne     t2, a2, bsg_mcs_mutex_release_exists_victim // victim_tail == lcl_as_glbl?
        ret                                                 // there really is no successor -- return
bsg_mcs_mutex_release_exists_victim:
        // someone added themselves to the queue and we have removed them
        // we need to put them back
        amoswap.w t2, t2, 0(a0)                             // usurper = swap(&mtx, victim_tail)
bsg_mcs_mutex_release_wait_on_successor:
        // Here we do not use the load-on-broken-reservation instructions
        // because if we are executing this code then there is a successor
        // that has executed the `amoswap.w.aq` instruction found in the acquire
        // function, and is in the process of updating the 'next' pointer
        // that we are polling.
        // We expect the wait time here to be on the order of 10s of cycles at worst.
        // Additionally, this is a corner case that we don't expect to execute often,
        // and the use of the LBR semantics increases the instruction footprint by
        // three ops.
        lw      t0, 4(a1)                                   // next = lcl->next
        bnez    t0, bsg_mcs_mutex_release_wait_on_successor // while (lcl->next != 0)
        bnez    t2, bsg_mcs_mutex_release_exists_usurper    // was there an usurper?
        // no usurper exists -- unlock our successor
        sw      t1, 0(t0)                                   // next->unlocked = 1
        ret
bsg_mcs_mutex_release_exists_usurper:       
        // usurper exists, set victims as successor
        sw      t0, 4(t2)                                   // usurper->next = next
        ret
