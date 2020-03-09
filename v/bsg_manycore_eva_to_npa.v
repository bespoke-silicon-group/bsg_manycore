/**
 *    bsg_manycore_eva_to_npa.v
 *
 *    this modules converts Endpoint Virtual Address (EVA) to Network Physical Address (NPA).
 *
 */


module bsg_manycore_eva_to_npa
  import bsg_manycore_pkg::*;
  #(parameter data_width_p="inv" // 32
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    
    , parameter num_tiles_x_p="inv"

    , parameter vcache_block_size_in_words_p="inv"
    , parameter vcache_size_p="inv" // vcache capacity in words
    , parameter vcache_sets_p="inv"

  )
  (
    input [data_width_p-1:0] eva_i  // byte addr
    , input dram_enable_i
    , input [x_cord_width_p-1:0] tgo_x_i
    , input [y_cord_width_p-1:0] tgo_y_i 

    , output logic [x_cord_width_p-1:0] x_cord_o
    , output logic [y_cord_width_p-1:0] y_cord_o
    , output logic [addr_width_p-1:0] epa_o   // word addr

    , output logic is_invalid_addr_o
  );

  // localparam
  //
  localparam vcache_word_offset_width_lp = `BSG_SAFE_CLOG2(vcache_block_size_in_words_p);
  localparam lg_vcache_size_lp = `BSG_SAFE_CLOG2(vcache_size_p);


  // figure out what type of EVA this is.
  `declare_bsg_manycore_global_addr_s;
  `declare_bsg_manycore_tile_group_addr_s;

  bsg_manycore_global_addr_s global_addr;
  bsg_manycore_tile_group_addr_s tile_group_addr;

  assign global_addr = eva_i;
  assign tile_group_addr = eva_i;

  wire is_dram_addr = eva_i[31];
  wire is_global_addr = global_addr.remote == 2'b01;
  wire is_tile_group_addr = tile_group_addr.remote == 3'b001;

  assign is_invalid_addr_o = ~(is_dram_addr | is_global_addr | is_tile_group_addr);

  
  // DRAM hash function
  localparam hash_bank_input_width_lp = data_width_p-1-2-vcache_word_offset_width_lp;
  localparam hash_bank_index_width_lp = $clog2(((2**hash_bank_input_width_lp)+(2*num_tiles_x_p)-1)/(num_tiles_x_p*2));

  logic [hash_bank_input_width_lp-1:0] hash_bank_input;
  logic [x_cord_width_p:0] hash_bank_lo;  // {bot_not_top, x_cord}
  logic [hash_bank_index_width_lp-1:0] hash_bank_index_lo;

  hash_function #(
    .banks_p(num_tiles_x_p*2)
    ,.width_p(hash_bank_input_width_lp)
    ,.vcache_sets_p(vcache_sets_p)
  ) hashb (
    .i(hash_bank_input)
    ,.bank_o(hash_bank_lo)
    ,.index_o(hash_bank_index_lo)
  );


  assign hash_bank_input = eva_i[2+vcache_word_offset_width_lp+:hash_bank_input_width_lp];


  always_comb begin
    if (is_dram_addr) begin
      if (dram_enable_i) begin
        y_cord_o = hash_bank_lo[x_cord_width_p]
          ? {y_cord_width_p{1'b1}}  // y-max
          : {y_cord_width_p{1'b0}};
        x_cord_o = hash_bank_lo[0+:x_cord_width_p];
        epa_o = {
          1'b0,
          {(addr_width_p-1-vcache_word_offset_width_lp-hash_bank_index_width_lp){1'b0}},
          hash_bank_index_lo,
          eva_i[2+:vcache_word_offset_width_lp]
        };

      end
      else begin
        // DRAM disabled.
        if (eva_i[30]) begin
          y_cord_o = '0;
          x_cord_o = '0;
          epa_o = {1'b1, eva_i[2+:addr_width_p-1]}; // HOST DRAM address
        end
        else begin
          y_cord_o = eva_i[2+lg_vcache_size_lp+x_cord_width_p]
            ? {y_cord_width_p{1'b1}}  // y-max
            : {y_cord_width_p{1'b0}};
          x_cord_o = eva_i[2+lg_vcache_size_lp+:x_cord_width_p];
          epa_o = {
            1'b0,
            {(addr_width_p-1-lg_vcache_size_lp){1'b0}},
            eva_i[2+:lg_vcache_size_lp]
          };
        end
      end
    end
    else if (is_global_addr) begin
      y_cord_o = y_cord_width_p'(global_addr.y_cord);
      x_cord_o = x_cord_width_p'(global_addr.x_cord);
      epa_o = {{(addr_width_p-epa_word_addr_width_gp){1'b0}}, global_addr.addr};
    end
    else if (is_tile_group_addr) begin
      y_cord_o = y_cord_width_p'(tile_group_addr.y_cord + tgo_y_i);
      x_cord_o = x_cord_width_p'(tile_group_addr.x_cord + tgo_x_i);
      epa_o = {{(addr_width_p-epa_word_addr_width_gp){1'b0}}, tile_group_addr.addr};
    end
    else begin
      // should never happen
      y_cord_o = '0;
      x_cord_o = '0;
      epa_o = '0;
    end
  end



endmodule
