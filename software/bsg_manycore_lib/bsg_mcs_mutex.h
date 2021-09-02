#pragma once
#ifdef __cplusplus
extern "C" {
#endif    

    // Must live in tile's local memory (DMEM)
    // Do not reorder the members in this struct
    // The assembly code in bsg_mcs_mutex.S depends on this ordering.
    typedef struct bsg_mcs_mutex_node {
        int unlocked;
        struct bsg_mcs_mutex_node *next;
    } bsg_mcs_mutex_node_t;    

    // Must live in dram
    typedef bsg_mcs_mutex_node_t* bsg_mcs_mutex_t;

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
    void bsg_mcs_mutex_acquire(bsg_mcs_mutex_t *mtx                //!< A pointer to an MCS mutex in DRAM
                               , bsg_mcs_mutex_node_t *lcl         //!< A local pointer to a node allocated in tile's local memory
                               , bsg_mcs_mutex_node_t *lcl_as_glbl //!< A global pointer to a node allocated in tile's local memory
        );

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
    void bsg_mcs_mutex_release(bsg_mcs_mutex_t *mtx                //!< A pointer to an MCS mutex in DRAM
                               , bsg_mcs_mutex_node_t *lcl         //!< A local pointer to a node allocated in tile's local memory
                               , bsg_mcs_mutex_node_t *lcl_as_glbl //!< A global pointer to a node allocated in tile's local memory
        );
#ifdef __cplusplus
}
#endif
