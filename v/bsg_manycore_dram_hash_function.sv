/**
 *    bsg_manycore_dram_hash_function.
 *
 *    EVA to dram NPA
 */

  // DRAM hash function
  // DRAM space is striped across vcaches at a cache line granularity.
  // Striping starts from the north vcaches, and alternates between north and south from inner layers to outer layers.

  // ungroup this module for synthesis.

`include "bsg_defines.sv"

module bsg_manycore_dram_hash_function 
  #(`BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)

    , `BSG_INV_PARAM(pod_x_cord_width_p)
    , `BSG_INV_PARAM(pod_y_cord_width_p)

    , `BSG_INV_PARAM(x_subcord_width_p)
    , `BSG_INV_PARAM(y_subcord_width_p)

    , `BSG_INV_PARAM(vcache_block_size_in_words_p)

    , parameter enable_ipoly_hashing_p=0
  )
  (
    input [data_width_p-1:0] eva_i // 32-bit byte address
    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i

    , output logic [addr_width_p-1:0] epa_o // word address
    , output logic [x_cord_width_p-1:0] x_cord_o
    , output logic [y_cord_width_p-1:0] y_cord_o
  );

  localparam vcache_word_offset_width_lp = `BSG_SAFE_CLOG2(vcache_block_size_in_words_p);
  localparam dram_index_width_lp = data_width_p-1-2-vcache_word_offset_width_lp-x_subcord_width_p-1;

  logic [dram_index_width_lp-1:0] dram_index;
  logic temp_y, new_y;
  logic [x_subcord_width_p-1:0] temp_x, new_x;
  assign {dram_index, temp_y, temp_x} = eva_i[2+vcache_word_offset_width_lp+:x_subcord_width_p+1+dram_index_width_lp];


  if (enable_ipoly_hashing_p) begin: ipoly
    // IPOLY hashing;
    bsg_hashing_ipoly #(
      .num_banks_p((2**x_subcord_width_p)+1)
      ,.upper_width_p(dram_index_width_lp)
    ) ipoly0 (
      .upper_bits_i(dram_index)
      ,.bank_id_i({temp_y, temp_x})
      ,.new_bank_id_o({new_y, new_x})
    );
  end
  else begin
    // default hashing;
    assign new_x = temp_x;
    assign new_y = temp_y;
  end


  wire [x_subcord_width_p-1:0] dram_x_subcord = new_x;
  wire [y_subcord_width_p-1:0] dram_y_subcord = {y_subcord_width_p{~new_y}};
  wire [pod_y_cord_width_p-1:0] dram_pod_y_cord = new_y
    ? pod_y_cord_width_p'(pod_y_i+1)
    : pod_y_cord_width_p'(pod_y_i-1);


  // NPA
  assign y_cord_o = {dram_pod_y_cord, dram_y_subcord};
  assign x_cord_o = {pod_x_i, dram_x_subcord};
  assign epa_o = {
    1'b0,
    {(addr_width_p-1-dram_index_width_lp-vcache_word_offset_width_lp){1'b0}},
    dram_index,
    eva_i[2+:vcache_word_offset_width_lp]
  };


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_dram_hash_function)
