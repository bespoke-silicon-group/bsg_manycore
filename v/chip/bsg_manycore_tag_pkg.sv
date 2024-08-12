
package bsg_manycore_tag_pkg;

  import bsg_tag_pkg::*;
  import bsg_link_pkg::*;
  import bsg_clk_gen_pearl_pkg::*;
  import bsg_link_pearl_pkg::*;

  typedef struct packed
  {
    bsg_tag_s                           global_x;
    bsg_tag_s                           global_y;
    bsg_tag_s                           sdr_disable;
    bsg_sdr_link_pearl_tag_lines_s      sdr;
    bsg_tag_s                           core_reset;
    bsg_clk_gen_pearl_tag_lines_s       clk_gen;
  }  bsg_manycore_subpod_tag_lines_s;
  localparam tag_subpod_local_els_gp = $bits(bsg_manycore_subpod_tag_lines_s)/$bits(bsg_tag_s);

  typedef struct packed
  {
    bsg_tag_s                           global_x;
    bsg_tag_s                           global_y;
    bsg_sdr_link_pearl_tag_lines_s      sdr;
    bsg_tag_s                           core_reset;
    bsg_clk_gen_pearl_tag_lines_s       clk_gen;
  }  bsg_manycore_pod_tag_lines_s;
  localparam tag_pod_local_els_gp = $bits(bsg_manycore_pod_tag_lines_s)/$bits(bsg_tag_s);

endpackage

