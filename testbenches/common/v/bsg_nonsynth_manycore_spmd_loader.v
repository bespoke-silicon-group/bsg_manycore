/**
 *  bsg_nonsynth_manycore_spmd_loader.v
 *
 */

`include "bsg_manycore_packet.vh"
`include "bsg_manycore_addr.vh"

`ifndef NUM_CODE_SECTIONS
	`define DEFAULT_CODE_SECTIONS
`endif

`ifndef CODE_SECTIONS
	`define DEFAULT_CODE_SECTIONS
`endif

`ifdef DEFAULT_CODE_SECTIONS
	`define NUM_CODE_SECTIONS 1
	`define CODE_SECTIONS `_bsg_dram_start_addr,`_bsg_dram_end_addr
`endif

module bsg_nonsynth_manycore_spmd_loader
  #(parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter load_id_width_p="inv"

    , parameter icache_entries_p="inv"
    , parameter epa_byte_addr_width_p="inv"
    , parameter dram_ch_addr_width_p="inv"
    , parameter dram_ch_num_p="inv"

    , parameter tgo_x_p="inv"
    , parameter tgo_y_p="inv"
    , parameter tg_x_dim_p="inv"
    , parameter tg_y_dim_p="inv"

    , parameter packet_width_lp =
      `bsg_manycore_packet_width(addr_width_p,data_width_p,
        x_cord_width_p,y_cord_width_p,load_id_width_p)

    // victim cache parameters
    , parameter init_vcache_p = 0
    , parameter vcache_sets_p = "inv"
    , parameter vcache_ways_p  = "inv" 

    // the data memory related parameters
    , parameter unsigned dmem_start_addr_lp = `_bsg_data_start_addr
    , parameter dmem_end_addr_lp = `_bsg_data_end_addr
    , parameter dmem_init_file_name = `_dmem_init_file_name

    // the dram related parameters
    // VCS do not support index larger than 32'h7fff_ffff
    , parameter unsigned dram_start_addr_lp = `_bsg_dram_start_addr
    , parameter unsigned dram_end_addr_lp = `_bsg_dram_end_addr  
    , parameter dram_init_file_name = `_dram_init_file_name

    // Only the address space derived from the following parameters is
    // loaded into the memory
    , parameter unsigned num_code_sections_p = `NUM_CODE_SECTIONS
    , parameter integer code_sections_p[0:(2*num_code_sections_p)-1] = '{`CODE_SECTIONS}
  )
  ( 
    input clk_i
    , input reset_i

    , output [packet_width_lp-1:0] packet_o
    , output v_o
    , input ready_i

    , input [y_cord_width_p-1:0] my_y_i
    , input [x_cord_width_p-1:0] my_x_i
  );

  // initialization files
  localparam dmem_size_lp = dmem_end_addr_lp - dmem_start_addr_lp;
  localparam dram_size_lp = dram_end_addr_lp - dram_start_addr_lp; 

  logic [7:0] DMEM [dmem_end_addr_lp:dmem_start_addr_lp];
  logic [7:0] DRAM [dram_end_addr_lp:dram_start_addr_lp];

  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p,load_id_width_p);
  `declare_bsg_manycore_dram_addr_s(dram_ch_addr_width_p);

  localparam config_byte_addr = 1 << ( epa_byte_addr_width_p-1);
  localparam unfreeze_addr = addr_width_p'(0) | config_byte_addr;

  logic var_v_o;
  bsg_manycore_packet_s packet;

  assign v_o = var_v_o;
  assign packet_o = packet;

  //---------------
  // Main Procedure 
  //---------------
  initial begin
    $readmemh(dmem_init_file_name, DMEM);
    $readmemh(dram_init_file_name, DRAM);
        
    var_v_o = 1'b0;
    wait(reset_i === 1'b0); //wait until the reset is done

    config_tile_group();
    init_icache();
    init_dmem();

    if(init_vcache_p)
      init_vcache();

    init_dram();
    unfreeze_tiles();

    @(posedge clk_i);  
    var_v_o = 1'b0;
  end

  // send_store
  // helper task
  task send_store (
    integer x_dest, integer y_dest, integer addr, integer payload
  );
    @(posedge clk_i);
    var_v_o = 1'b1;
    packet.payload = payload;
    packet.addr = addr;
    packet.op = `ePacketOp_remote_store;
    packet.op_ex =  4'b1111;
    packet.x_cord = x_dest;
    packet.y_cord = y_dest;
    packet.src_x_cord = my_x_i;
    packet.src_y_cord = my_y_i;

    @(negedge clk_i);
    wait(ready_i === 1'b1);
  endtask


  // init_icache
  // initialize the icache with the first 4KB instructions in DRAM
  task init_icache();
    integer x, y, icache_addr, dram_byte_addr;
    logic [data_width_p-1:0] instr;

    for (y = tgo_y_p; y < tgo_y_p + tg_y_dim_p; y++) begin
      for (x = tgo_x_p; x < tgo_x_p + tg_x_dim_p; x++) begin
        $display("[INFO][LOADER] Initializing ICACHE, y_cord=%02d, x_cord=%02d, range=0000 - %h",
          y, x, icache_entries_p-1);

        for (icache_addr = 0; icache_addr < icache_entries_p; icache_addr++) begin

          dram_byte_addr = icache_addr << 2;

          instr = {
            DRAM[dram_byte_addr+3],
            DRAM[dram_byte_addr+2], 
            DRAM[dram_byte_addr+1],
            DRAM[dram_byte_addr+0]
          };

          send_store(x,y,icache_addr|(1<<(`MC_ICACHE_MASK_BITS-2)), instr);

        end 
      end
    end
  endtask 

  // init_dmem
  //
  task init_dmem();

    integer x, y, dmem_addr, init_data;

    for (y = tgo_y_p; y < tgo_y_p + tg_y_dim_p; y++) begin
      for (x = tgo_x_p; x < tgo_x_p + tg_x_dim_p; x++) begin

        $display("[INFO][LOADER] Initializing DMEM, y_cord=%02d, x_cord=%02d, range=%h - %h (byte)",
          y, x, dmem_start_addr_lp, dmem_end_addr_lp);

        for (dmem_addr = dmem_start_addr_lp; dmem_addr < dmem_end_addr_lp; dmem_addr=dmem_addr+4) begin
          init_data = {DMEM[dmem_addr+3], DMEM[dmem_addr+2], DMEM[dmem_addr+1], DMEM[dmem_addr]};

          // SHX: This is used to fixe the
          // gcc-toolchain bugs, in some case, it put the initilized data into .bss and .sbss section.
          // which should be in .data or .sdata seciton. 
          //
          // Does the RISC-V toolchain assumes that all uninitilized data are zeros, so they put the zero
          // initilized data into .bss and .sbss section?
          if (init_data === 32'bx)
            init_data = 32'b0;

          send_store(x,y,dmem_addr>>2, init_data);

        end 
      end
    end
  endtask 

 
  // init_dram 
  //
  task init_dram();
    integer dram_addr;
    logic [data_width_p-1:0] payload;
    bsg_manycore_dram_addr_s dram_addr_cast; 

    for (integer sec = 0; sec < num_code_sections_p; sec = sec + 1) begin
      $display("[INFO][LOADER] Initializing DRAM section:%0d, range=%h - %h",
        sec+1, code_sections_p[2*sec], code_sections_p[2*sec+1]);
      for (dram_addr = code_sections_p[2*sec]; dram_addr < code_sections_p[2*sec+1]; dram_addr=dram_addr+4) begin
        dram_addr_cast = dram_addr; 
        payload = {DRAM[dram_addr+3], DRAM[dram_addr+2], DRAM[dram_addr+1], DRAM[dram_addr]};
        send_store(dram_addr_cast.x_cord, {y_cord_width_p{1'b1}}, dram_addr>>2, payload); 
      end
    end
  endtask 


  // unfreeze_tiles
  //
  task unfreeze_tiles();
    integer x, y;

    $display("[INFO][LOADER] Unfreezing tiles...");

    for (y = tgo_y_p; y < tgo_y_p + tg_y_dim_p; y++) begin
      for (x = tgo_x_p; x < tgo_x_p + tg_x_dim_p; x++) begin
        send_store(x, y, unfreeze_addr>>2,'b0);
      end
    end

  endtask 

  // Task to initialize the victim cache
  //
  task init_vcache();
    integer x_cord, y_cord, tag_addr ;

    $display("initializing the victim caches, sets=%0d, ways=%0d", vcache_sets_p, vcache_ways_p);
    for (x_cord =0; x_cord < dram_ch_num_p; x_cord++) begin
      for (tag_addr =0; tag_addr < vcache_sets_p * vcache_ways_p; tag_addr++)begin
        @(posedge clk_i);
        var_v_o = 1'b1; 

        packet.payload    =  'b0;
        packet.addr       =  (1<<(dram_ch_addr_width_p-1)) | (tag_addr << 3) ; 
        packet.op         = `ePacketOp_remote_store;
        packet.op_ex      =  4'b1111;
        packet.x_cord     = x_cord;
        packet.y_cord     = {y_cord_width_p{1'b1}};
        packet.src_x_cord = my_x_i;
        packet.src_y_cord = my_y_i;

        @(negedge clk_i);
        wait(ready_i === 1'b1);
      end
    end
  endtask 


  // config_tile_group
  //
  task config_tile_group();

    integer x, y;

    $display("[INFO][LOADER] Configuring the Tile Group Origin. dim(y,x)=(%0d,%0d).",
      tg_y_dim_p, tg_x_dim_p);

    for (y = tgo_y_p; y < tgo_y_p + tg_y_dim_p; y++) begin
      for (x = tgo_x_p; x < tgo_x_p + tg_x_dim_p; x++) begin

        $display("[INFO][LOADER] Tile (y,x)=(%0d,%0d) Set to Tile Group Origin (y,x)=(%0d,%0d)",
          y, x, tgo_y_p, tgo_x_p);

        send_store(x, y, (config_byte_addr | 4) >>2, tgo_x_p);
        send_store(x, y, (config_byte_addr | 8) >>2, tgo_y_p);
      end
    end
  endtask 


endmodule
