/**
 *    bsg_manycore_dram_hash_function.
 *
 *    EVA to dram NPA
 */

  // DRAM hash function
  // DRAM space is striped across vcaches at a cache line granularity.
  // Striping starts from the north vcaches, and alternates between north and south from inner layers to outer layers.

  // ungroup this module for synthesis.

module bsg_manycore_dram_hash_function 
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter pod_x_cord_width_p="inv"
    , parameter pod_y_cord_width_p="inv"

    , parameter x_subcord_width_p="inv"
    , parameter y_subcord_width_p="inv"

    , parameter num_vcache_rows_p="inv"
    , parameter vcache_block_size_in_words_p="inv"
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


  wire [vcache_row_id_width_lp-1:0] vcache_row_id = eva_i[2+vcache_word_offset_width_lp+x_subcord_width_p+:vcache_row_id_width_lp];
  wire [x_subcord_width_p-1:0] dram_x_subcord = eva_i[2+vcache_word_offset_width_lp+:x_subcord_width_p];
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

  wire [dram_index_width_lp-1:0] dram_index = eva_i[2+vcache_word_offset_width_lp+x_subcord_width_p+vcache_row_id_width_lp+:dram_index_width_lp];


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
