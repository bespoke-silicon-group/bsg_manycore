/**
 *  bsg_mem_cfg_pkg.v
 */

package bsg_mem_cfg_pkg;

  localparam max_cfgs = 16;
  localparam lg_max_cfgs = `BSG_SAFE_CLOG2(max_cfgs); 

  typedef enum bit [lg_max_cfgs-1:0] {
    e_mem_cfg_default    = 0
    , e_mem_cfg_infinite = 1
  } bsg_mem_cfg_e;

endpackage
