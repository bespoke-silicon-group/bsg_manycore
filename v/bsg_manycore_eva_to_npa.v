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
 *
 *    Modifying this mapping requires the same change in the following files.
 *    - Cuda-lite
 *    https://github.com/bespoke-silicon-group/bsg_replicant/blob/master/libraries/bsg_manycore_eva.cpp
 *    - SPMD testbench
 *    https://github.com/bespoke-silicon-group/bsg_manycore/blob/master/software/py/nbf.py
 */


module bsg_manycore_eva_to_npa
  import bsg_manycore_pkg::*;
  #(parameter data_width_p="inv" // 32
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter pod_x_cord_width_p="inv"
    , parameter pod_y_cord_width_p="inv"
 
    , parameter num_tiles_x_p="inv"
    , parameter num_tiles_y_p="inv"
    , parameter x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)

    , parameter num_vcache_rows_p = "inv"
    , parameter vcache_block_size_in_words_p="inv"  // block size in vcache
    , parameter vcache_size_p="inv" // vcache capacity in words
    , parameter vcache_sets_p="inv" // number of sets in vcache
  )
  (
    // EVA 32-bit virtual address used by vanilla core
    input [data_width_p-1:0] eva_i  // byte addr
    , input [x_subcord_width_lp-1:0] tgo_x_i // tile-group origin x
    , input [y_subcord_width_lp-1:0] tgo_y_i // tile-group origin y

    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i

    // When DRAM mode is enabled, DRAM EVA space is striped across vcaches at a cache line granularity.
    // When DRAM mode is disabled, vcaches are only used as block memory, and the striping is disabled,
    // and some upper addresses are mapped to host-side memory.
    , input dram_enable_i // DRAM MODE enable

    // NPA (x,y,EPA)
    , output logic [x_cord_width_p-1:0] x_cord_o  // destination x_cord (global)
    , output logic [y_cord_width_p-1:0] y_cord_o  // destination y_cord (global)
    , output logic [addr_width_p-1:0] epa_o       // endpoint physical address (word addr)

    // EVA does not map to any valid remote NPA location.
    , output logic is_invalid_addr_o
  );

  // localparam
  //
  localparam vcache_word_offset_width_lp = `BSG_SAFE_CLOG2(vcache_block_size_in_words_p);
  localparam lg_vcache_size_lp = `BSG_SAFE_CLOG2(vcache_size_p);
  localparam vcache_row_id_width_lp = `BSG_SAFE_CLOG2(2*num_vcache_rows_p);


  // figure out what type of EVA this is.
  bsg_manycore_global_addr_s global_addr;
  bsg_manycore_tile_group_addr_s tile_group_addr;

  assign global_addr = eva_i;
  assign tile_group_addr = eva_i;

  wire is_dram_addr = eva_i[31];
  wire is_global_addr = global_addr.remote == 2'b01;
  wire is_tile_group_addr = tile_group_addr.remote == 3'b001;


  
  // DRAM hash function
  // DRAM space is striped across vcaches at a cache line granularity.
  // Striping starts from the north vcaches, and alternates between north and south from inner layers to outer layers.
  
  logic [x_cord_width_p-1:0] dram_x_cord_lo;
  logic [y_cord_width_p-1:0] dram_y_cord_lo;
  logic [addr_width_p-1:0] dram_epa_lo;

  bsg_manycore_dram_hash_function #(
    .data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.pod_x_cord_width_p(pod_x_cord_width_p)
    ,.pod_y_cord_width_p(pod_y_cord_width_p)
    ,.x_subcord_width_p(x_subcord_width_lp)
    ,.y_subcord_width_p(y_subcord_width_lp)
    ,.num_vcache_rows_p(num_vcache_rows_p)
    ,.vcache_block_size_in_words_p(vcache_block_size_in_words_p)
  ) dram_hash (
    .eva_i(eva_i)
    ,.pod_x_i(pod_x_i)
    ,.pod_y_i(pod_y_i)

    ,.x_cord_o(dram_x_cord_lo)
    ,.y_cord_o(dram_y_cord_lo)
    ,.epa_o(dram_epa_lo)
  );


  // NO DRAM mode hash function
  wire [x_subcord_width_lp-1:0] no_dram_x_subcord = eva_i[2+lg_vcache_size_lp+:x_subcord_width_lp];
  wire [vcache_row_id_width_lp-1:0] no_dram_vcache_row_id = eva_i[2+lg_vcache_size_lp+x_subcord_width_lp+:vcache_row_id_width_lp];
  wire [y_subcord_width_lp-1:0] no_dram_y_subcord;
  wire [pod_y_cord_width_p-1:0] no_dram_pod_y_cord = no_dram_vcache_row_id[0]
    ? pod_y_cord_width_p'(pod_y_i+1)
    : pod_y_cord_width_p'(pod_y_i-1);

  if (num_vcache_rows_p == 1) begin
    assign no_dram_y_subcord = {y_subcord_width_lp{~no_dram_vcache_row_id[0]}};
  end
  else begin
    assign no_dram_y_subcord = {
      {(y_subcord_width_lp+1-vcache_row_id_width_lp){~no_dram_vcache_row_id[0]}},
      (no_dram_vcache_row_id[0]
        ?  no_dram_vcache_row_id[vcache_row_id_width_lp-1:1]
        : ~no_dram_vcache_row_id[vcache_row_id_width_lp-1:1])
    };
  end



  // EVA->NPA table
  always_comb begin
    is_invalid_addr_o = 1'b0;

    if (is_dram_addr) begin
      if (dram_enable_i) begin
        y_cord_o = dram_y_cord_lo;
        x_cord_o = dram_x_cord_lo;
        epa_o = dram_epa_lo;
      end
      else begin
        // DRAM disabled mode is used when vcaches are used as block RAMs,
        // in which case the tags will be manually written in the vcaches
        // to prevent cache miss.
        // striping is disabled.
        y_cord_o = {no_dram_pod_y_cord, no_dram_y_subcord};
        x_cord_o = {pod_x_i, no_dram_x_subcord};

        epa_o = {
          1'b0,
          {(addr_width_p-1-lg_vcache_size_lp){1'b0}},
          eva_i[2+:lg_vcache_size_lp]
        };
      end
    end
    else if (is_global_addr) begin
      // global-addr
      // x,y-cord and EPA is directly encoded in EVA.
      y_cord_o = y_cord_width_p'(global_addr.y_cord);
      x_cord_o = x_cord_width_p'(global_addr.x_cord);
      epa_o = {{(addr_width_p-global_epa_word_addr_width_gp){1'b0}}, global_addr.addr};
    end
    else if (is_tile_group_addr) begin
      // tile-group addr
      // tile-coordinate in the EVA is added to the tile-group origin register.
      y_cord_o = {pod_y_i, y_subcord_width_lp'(tile_group_addr.y_cord + tgo_y_i)};
      x_cord_o = {pod_x_i, x_subcord_width_lp'(tile_group_addr.x_cord + tgo_x_i)};
      epa_o = {{(addr_width_p-tile_group_epa_word_addr_width_gp){1'b0}}, tile_group_addr.addr};
    end
    else begin
      // should never happen
      y_cord_o = '0;
      x_cord_o = '0;
      epa_o = '0;
      is_invalid_addr_o = 1'b1;
    end
  end


endmodule
