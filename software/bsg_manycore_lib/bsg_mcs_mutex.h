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

    void bsg_mcs_mutex_acquire(bsg_mcs_mutex_t *mtx                //!< An MCS mutex
                               , bsg_mcs_mutex_node_t *lcl         //!< A local pointer to a node allocated in tile's local memory
                               , bsg_mcs_mutex_node_t *lcl_as_glbl //!< A global pointer to a node allocated in tile's local memory
        );

    void bsg_mcs_mutex_release(bsg_mcs_mutex_t *mtx                //!< An MCS mutex
                               , bsg_mcs_mutex_node_t *lcl         //!< A local pointer to a node allocated in tile's local memory
                               , bsg_mcs_mutex_node_t *lcl_as_glbl //!< A global pointer to a node allocated in tile's local memory
        );
#ifdef __cplusplus
}
#endif
