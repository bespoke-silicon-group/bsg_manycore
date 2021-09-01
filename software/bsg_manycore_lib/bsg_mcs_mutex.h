#pragma once
#ifdef __cplusplus
extern "C" {
#endif    

    // must live in tile's local memory (DMEM)
    typedef struct bsg_mcs_mutex_node {
        int unlocked;
        struct bsg_mcs_mutex_node *next;
    } bsg_mcs_mutex_node_t;    

    // must live in dram
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
