/**
 *  bsg_manycore_mem_cfg_pkg.v
 */

package bsg_manycore_mem_cfg_pkg;

  `include "bsg_defines.v"

  localparam max_cfgs = 128;
  localparam lg_max_cfgs = `BSG_SAFE_CLOG2(max_cfgs); 

  // Manycore Memory Configuration enum
  // 
  // The enum naming convention describes which memory system is being used.
  // It roughly divides into three levels of hierarchy.
  //
  // e_{cache/block_mem}_{interface}_{backend_memory}
  //    
  //
  // LEVEL 1) What is attached to manycore link on the south side. This could be the
  //          last level of hierarchy, if it's block mem, or infinite memory, for
  //          example.
  //          - e_vcache_blocking_*
  //          - e_vcache_non_blocking_*
  //          - e_infinite_memory
  //
  // LEVEL 2) What interface does cache DMA interface converts to.
  //          - dma_ (no interface conversion)
  //          - axi4_ (convert to axi4)
  //          - dmc_ (convert to bsg_dmc interface)
  //          - aib_ (convert to AIB interface)
  //
  // LEVEL 3) What is being used as the last main memory.
  //          - nonsynth_mem 
  //          - lpddr4 (ex. micron sim model)
  //          - f1_ddr
  //

  typedef enum bit [lg_max_cfgs-1:0] {

    // LEVEL 1) zero-latency, infinite capacity block mem.
    //          (uses associative array)
    e_infinite_mem
    
    // LEVEL 1) bsg_manycore_vcache (blocking)
    // LEVEL 2) bsg_cache_to_axi
    // LEVEl 3) bsg_nonsynth_manycore_axi_mem
    , e_vcache_blocking_axi4_nonsynth_mem
    , e_vcache_blocking_axi4_f1_dram
    , e_vcache_blocking_axi4_xilinx_hbm_direct_no_ro

  } bsg_manycore_mem_cfg_e;

endpackage
