/**
 *  memory_system.v
 *
 */



module memory_system
  import bsg_mem_cfg_pkg::*;
  #(parameter bsg_mem_cfg_e mem_cfg_p=e_mem_cfg_default
    , parameter bsg_global_x_p="inv" 
    , parameter bsg_global_y_p="inv"

    , parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter load_id_width_p="inv"

    , parameter sets_p="inv"
    , parameter ways_p="inv"
    , parameter block_size_in_words_p="inv"

    , parameter axi_id_width_p = "inv"
    , parameter axi_addr_width_p = "inv"
    , parameter axi_data_width_p = "inv"
    , parameter axi_burst_len_p = "inv"

    , parameter bsg_dram_included_p = "inv"
    , parameter bsg_dram_size_p = "inv"

    , parameter link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input [bsg_global_x_p-1:0][link_sif_width_lp-1:0] link_sif_i
    , output [bsg_global_x_p-1:0][link_sif_width_lp-1:0] link_sif_o
  );

  if (mem_cfg_p == e_mem_cfg_default) begin
    bsg_cache_wrapper_axi #(
      .bsg_global_x_p(bsg_global_x_p)
      ,.bsg_global_y_p(bsg_global_y_p)
    
      ,.data_width_p(data_width_p)
      ,.addr_width_p(addr_width_p)
      ,.x_cord_width_p(x_cord_width_p)
      ,.y_cord_width_p(y_cord_width_p)
      ,.load_id_width_p(load_id_width_p)

      ,.block_size_in_words_p(block_size_in_words_p)
      ,.sets_p(sets_p)
      ,.ways_p(ways_p)

      ,.axi_id_width_p(axi_id_width_p)
      ,.axi_addr_width_p(axi_addr_width_p)
      ,.axi_data_width_p(axi_data_width_p)
      ,.axi_burst_len_p(axi_burst_len_p)
    ) cache_axi (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      
      ,.link_sif_i(link_sif_i)
      ,.link_sif_o(link_sif_o)
    );
  end
  else begin
    initial begin
      assert("mem_cfg_p" == "undefined") else $error("undefined mem_cfg.");
    end
  end

endmodule
