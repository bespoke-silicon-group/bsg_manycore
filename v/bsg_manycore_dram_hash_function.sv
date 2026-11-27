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

    , `BSG_INV_PARAM(num_vcache_rows_p)
    , `BSG_INV_PARAM(vcache_block_size_in_words_p)

    , `BSG_INV_PARAM(ipoly_hashing_p)
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
  localparam vcache_row_id_width_lp = `BSG_SAFE_CLOG2(2*num_vcache_rows_p);
  localparam dram_index_width_lp = data_width_p-1-2-vcache_word_offset_width_lp-x_subcord_width_p-vcache_row_id_width_lp;

  logic [dram_index_width_lp-1:0] dram_index;
  logic [vcache_row_id_width_lp-1:0] temp_row_id, vcache_row_id;
  logic [x_subcord_width_p-1:0] temp_x, new_x;
  assign {dram_index, temp_row_id, temp_x} = eva_i[2+vcache_word_offset_width_lp+:x_subcord_width_p+vcache_row_id_width_lp+dram_index_width_lp];


  if (ipoly_hashing_p) begin: ipoly
    // IPOLY hashing;
    // The bank id is {vcache_row_id, x_subcord}.
    bsg_hashing_ipoly #(
      .num_banks_p(2**(x_subcord_width_p+vcache_row_id_width_lp))
      ,.upper_width_p(dram_index_width_lp)
    ) ipoly0 (
      .upper_bits_i(dram_index)
      ,.bank_id_i({temp_row_id, temp_x})
      ,.new_bank_id_o({vcache_row_id, new_x})
    );
  end
  else begin
    // default hashing;
    assign new_x = temp_x;
    assign vcache_row_id = temp_row_id;
  end


  wire [x_subcord_width_p-1:0] dram_x_subcord = new_x;
  wire [y_subcord_width_p-1:0] dram_y_subcord;
  wire [pod_y_cord_width_p-1:0] dram_pod_y_cord = vcache_row_id[0]
    ? pod_y_cord_width_p'(pod_y_i+1)
    : pod_y_cord_width_p'(pod_y_i-1);

  if (num_vcache_rows_p == 1) begin
    assign dram_y_subcord = {y_subcord_width_p{~vcache_row_id[0]}};
  end
  else begin
    assign dram_y_subcord = {
      {(y_subcord_width_p+1-vcache_row_id_width_lp){~vcache_row_id[0]}},
      (vcache_row_id[0]
        ?  vcache_row_id[vcache_row_id_width_lp-1:1]
        : ~vcache_row_id[vcache_row_id_width_lp-1:1])
    };
  end


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
