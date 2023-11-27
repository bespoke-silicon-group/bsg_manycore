/**
 *    bsg_manycore_network_cfg_pkg.v
 *
 */


package bsg_manycore_network_cfg_pkg;

  `include "bsg_defines.sv"

  localparam max_cfgs = 128;
  localparam lg_max_cfgs = `BSG_SAFE_CLOG2(max_cfgs); 

  typedef enum bit [lg_max_cfgs-1:0] {
    // Crossbar network
    e_network_crossbar

    // 2D mesh
    , e_network_mesh

    // half ruche X
    , e_network_half_ruche_x

    // placeholder for max enum val
    , e_network_max_val

  } bsg_manycore_network_cfg_e;


endpackage
