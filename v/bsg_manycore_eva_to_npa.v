/**
 *    bsg_manycore_eva_to_npa.v
 *
 *    This modules converts Endpoint Virtual Address (EVA) (32-bit) to Network Physical Address (NPA) (x,y-cord + EPA).
 *    Some EVA space maps to endpoint-specific address space. For example, vanilla core maps some portion of its EVA to its own local DMEM.
 *    It is very conceivable that different kinds of accelerators will map the portion of EVA differently to its local resources.
 *    This converter handles the mapping of EVA that is universal to all endpoints connected to the mesh network.
 *      1) DRAM
 *      2) Global
 *      3) Tile-Group
 *      4) Tile-Group-Shared Memory
 *
 */


module bsg_manycore_eva_to_npa
  import bsg_manycore_pkg::*;
  #(parameter data_width_p="inv" // 32
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    
    , parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"

    , parameter vcache_block_size_in_words_p="inv"  // block size in vcache
    , parameter vcache_size_p="inv" // vcache capacity in words
    , parameter vcache_sets_p="inv" // number of sets in vcache

  )
  (
    // EVA 32-bit virtual address used by vanilla core
    input [data_width_p-1:0] eva_i  // byte addr
    , input [x_cord_width_p-1:0] tgo_x_i // tile-group origin x
    , input [y_cord_width_p-1:0] tgo_y_i // tile-group origin y

    // When DRAM mode is enabled, DRAM EVA space is striped across vcaches at a cache line granularity.
    // When DRAM mode is disabled, vcaches are only used as block memory, and the striping is disabled,
    // and some upper addresses are mapped to host-side memory.
    , input dram_enable_i // DRAM MODE enable

    // NPA (x,y,EPA)
    , output logic [x_cord_width_p-1:0] x_cord_o  // destination x_cord
    , output logic [y_cord_width_p-1:0] y_cord_o  // destination y_cord
    , output logic [addr_width_p-1:0] epa_o       // endpoint physical address (word addr)

    // EVA does not map to any valid remote NPA location.
    , output logic is_invalid_addr_o
  );

  // localparam
  //
  localparam vcache_word_offset_width_lp = `BSG_SAFE_CLOG2(vcache_block_size_in_words_p);
  localparam lg_vcache_size_lp = `BSG_SAFE_CLOG2(vcache_size_p);


  // TODO borna: Use input signals instead of local params below
  localparam x_tg_dim_lp = 4;                                      // tile group x dimension
  localparam y_tg_dim_lp = 4;                                      // tile group y dimension
  localparam x_cord_width_lp = `BSG_SAFE_CLOG2(x_tg_dim_lp);       // width of x cord bits in shared address
  localparam y_cord_width_lp = `BSG_SAFE_CLOG2(y_tg_dim_lp);       // width of x cord bits in shared address
  localparam dmem_start_addr_lp = 16'h400;                         // Address of DMEM[0] 


  // figure out what type of EVA this is.
  `declare_bsg_manycore_global_addr_s;
  `declare_bsg_manycore_tile_group_addr_s;
  `declare_bsg_manycore_shared_addr_s(x_cord_width_lp,y_cord_width_lp);

  bsg_manycore_global_addr_s global_addr;
  bsg_manycore_tile_group_addr_s tile_group_addr;
  bsg_manycore_shared_addr_s shared_addr;

  assign global_addr = eva_i;
  assign tile_group_addr = eva_i;
  assign shared_addr = eva_i;

  wire is_dram_addr = eva_i[31];
  wire is_global_addr = global_addr.remote == 2'b01;
  wire is_tile_group_addr = tile_group_addr.remote == 3'b001;
  wire is_shared_addr = shared_addr.remote == 5'b00001;

  assign is_invalid_addr_o = ~(is_dram_addr | is_global_addr | is_tile_group_addr | is_shared_addr);

  
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


  // Tile Group Shared Memory Hash Function
  logic [x_cord_width_lp-1:0] shared_x_lo;
  logic [y_cord_width_lp-1:0] shared_y_lo;
  logic [epa_word_addr_width_gp-1:0] shared_epa_lo;

  hash_function_shared #(
    .width_p(max_local_offset_width_gp+max_x_cord_width_gp+max_y_cord_width_gp-1)
    ,.x_cord_width_lp(x_cord_width_lp)
    ,.y_cord_width_lp(y_cord_width_lp)
    ,.hash_width_lp(4)
  ) hashb_shared (
    .i(shared_addr.addr)
    ,.hash(shared_addr.hash)
    ,.x_o(shared_x_lo)
    ,.y_o(shared_y_lo)
    ,.addr_o(shared_epa_lo)
  );


  always_comb begin
    if (is_dram_addr) begin
      if (dram_enable_i) begin
        y_cord_o = hash_bank_lo[x_cord_width_p]
          ? (y_cord_width_p)'(num_tiles_y_p+1) // DRAM ports are directly below the manycore tiles.
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
          y_cord_o = (y_cord_width_p)'(1);
          x_cord_o = '0;
          epa_o = {1'b1, eva_i[2+:addr_width_p-1]}; // HOST DRAM address
        end
        else begin
          y_cord_o = eva_i[2+lg_vcache_size_lp+x_cord_width_p]
            ? (y_cord_width_p)'(num_tiles_y_p+1)  // DRAM ports are directly below the manycore tiles.
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
      // global-addr
      // x,y-cord and EPA is directly encoded in EVA.
      y_cord_o = y_cord_width_p'(global_addr.y_cord);
      x_cord_o = x_cord_width_p'(global_addr.x_cord);
      epa_o = {{(addr_width_p-epa_word_addr_width_gp){1'b0}}, global_addr.addr};
    end
    else if (is_tile_group_addr) begin
      // tile-group addr
      // tile-coordinate in the EVA is added to the tile-group origin register.
      y_cord_o = y_cord_width_p'(tile_group_addr.y_cord + tgo_y_i);
      x_cord_o = x_cord_width_p'(tile_group_addr.x_cord + tgo_x_i);
      epa_o = {{(addr_width_p-epa_word_addr_width_gp){1'b0}}, tile_group_addr.addr};
    end
    else if (is_shared_addr) begin
      // tile-group shared addr
      // tile-coordinate in the EVA is added to the tile-group origin register.
      // Dmem start address is added to the local offset extracted from eva
      y_cord_o = y_cord_width_p'(shared_y_lo + tgo_y_i);
      x_cord_o = x_cord_width_p'(shared_x_lo + tgo_x_i);
      epa_o = { {(addr_width_p-epa_word_addr_width_gp){1'b0}},
                {{shared_epa_lo + dmem_start_addr_lp}} };
   end
    else begin
      // should never happen
      y_cord_o = '0;
      x_cord_o = '0;
      epa_o = '0;
    end
  end


endmodule
