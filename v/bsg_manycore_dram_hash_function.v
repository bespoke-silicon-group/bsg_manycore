/**
 *    bsg_manycore_dram_hash_function.
 *
 *    EVA to dram NPA
 */

  // DRAM hash function
  // DRAM space is striped across vcaches at a cache line granularity.
  // Striping starts from the north vcaches, and alternates between north and south from inner layers to outer layers.

  // ungroup this module for synthesis.

`include "bsg_defines.v"

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

  wire [dram_index_width_lp-1:0] dram_index = eva_i[2+vcache_word_offset_width_lp+x_subcord_width_p+vcache_row_id_width_lp+:dram_index_width_lp];



  // ipoly hashing (xy)  start;
  ///*
  logic [x_subcord_width_p-1:0] xcord_tmp;
  logic is_south;

  if (x_subcord_width_p == 4) begin
    assign xcord_tmp[0] = dram_x_subcord[0]
                      ^ dram_index[0]   
                      ^ dram_index[3]   
                      ^ dram_index[5]   
                      ^ dram_index[6]   
                      ^ dram_index[9]   
                      ^ dram_index[10]   
                      ^ dram_index[11]   
                      ^ dram_index[12]   
                      ^ dram_index[13];
    assign xcord_tmp[1] = dram_x_subcord[1]
                      ^ dram_index[1]
                      ^ dram_index[4]
                      ^ dram_index[6]
                      ^ dram_index[7]
                      ^ dram_index[10]
                      ^ dram_index[11]
                      ^ dram_index[12]
                      ^ dram_index[13]
                      ^ dram_index[14];
    assign xcord_tmp[2] = dram_x_subcord[2]
                      ^ dram_index[0]
                      ^ dram_index[2]
                      ^ dram_index[3]
                      ^ dram_index[6]
                      ^ dram_index[7]
                      ^ dram_index[8]
                      ^ dram_index[9]
                      ^ dram_index[10]
                      ^ dram_index[14];
    assign xcord_tmp[3] = dram_x_subcord[3]
                      ^ dram_index[1]
                      ^ dram_index[3]
                      ^ dram_index[4]
                      ^ dram_index[7]
                      ^ dram_index[8]
                      ^ dram_index[9]
                      ^ dram_index[10]
                      ^ dram_index[11];
    assign is_south = vcache_row_id[0]
                ^ dram_index[2]
                ^ dram_index[4]
                ^ dram_index[5]
                ^ dram_index[8]
                ^ dram_index[9]
                ^ dram_index[10]
                ^ dram_index[11]
                ^ dram_index[12];
  end
  else if (x_subcord_width_p == 5) begin
    assign xcord_tmp[0] = dram_x_subcord[0]
                        ^ dram_index[0]
                        ^ dram_index[5]
                        ^ dram_index[6]
                        ^ dram_index[10]
                        ^ dram_index[12]
                        ^ dram_index[15]
                        ^ dram_index[16]
                        ^ dram_index[17]
                        ^ dram_index[18];
    assign xcord_tmp[1] = dram_x_subcord[1]
                        ^ dram_index[0]
                        ^ dram_index[1]
                        ^ dram_index[5]
                        ^ dram_index[7]
                        ^ dram_index[10]
                        ^ dram_index[11]
                        ^ dram_index[12]
                        ^ dram_index[13]
                        ^ dram_index[15];
    assign xcord_tmp[2] = dram_x_subcord[2]
                        ^ dram_index[1]
                        ^ dram_index[2]
                        ^ dram_index[6]
                        ^ dram_index[8]
                        ^ dram_index[11]
                        ^ dram_index[12]
                        ^ dram_index[13]
                        ^ dram_index[14]
                        ^ dram_index[16];
    assign xcord_tmp[3] = dram_x_subcord[3]
                        ^ dram_index[2]
                        ^ dram_index[3]
                        ^ dram_index[7]
                        ^ dram_index[9]
                        ^ dram_index[12]
                        ^ dram_index[13]
                        ^ dram_index[14]
                        ^ dram_index[15]
                        ^ dram_index[17];
    assign xcord_tmp[4] = dram_x_subcord[4]
                        ^ dram_index[3]
                        ^ dram_index[4]
                        ^ dram_index[8]
                        ^ dram_index[10]
                        ^ dram_index[13]
                        ^ dram_index[14]
                        ^ dram_index[15]
                        ^ dram_index[16]
                        ^ dram_index[18];
    assign is_south = vcache_row_id[0]
                    ^ dram_index[4]
                    ^ dram_index[5]
                    ^ dram_index[9]
                    ^ dram_index[11]
                    ^ dram_index[14]
                    ^ dram_index[15]
                    ^ dram_index[16]
                    ^ dram_index[17];
  end
  else begin
    $error("Unsupported banks for IPOLY hashing.");
  end
//*/
// ipoly hashing (xy) end;



  wire [pod_y_cord_width_p-1:0] dram_pod_y_cord = is_south
    ? pod_y_cord_width_p'(pod_y_i+1)
    : pod_y_cord_width_p'(pod_y_i-1);

  wire [y_subcord_width_p-1:0] dram_y_subcord;
  if (num_vcache_rows_p == 1) begin
    assign dram_y_subcord = {y_subcord_width_p{~is_south}};
  end

  // NPA
  assign y_cord_o = {dram_pod_y_cord, dram_y_subcord};
  assign x_cord_o = {pod_x_i, xcord_tmp};
  assign epa_o = {
    1'b0,
    {(addr_width_p-1-dram_index_width_lp-vcache_word_offset_width_lp){1'b0}},
    dram_index,
    eva_i[2+:vcache_word_offset_width_lp]
  };


endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_dram_hash_function)
