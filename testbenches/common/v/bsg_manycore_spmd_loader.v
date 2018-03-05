`include "bsg_manycore_packet.vh"

//should we shut down the dynamic feature of the arbiter ?
//`define  SHUT_DY_ARB


module bsg_manycore_spmd_loader

import bsg_noc_pkg   ::*; // {P=0, W, E, N, S}

 #( parameter mem_size_p      = -1 // size of mem to be loaded  (bytes) (?)
   ,parameter data_width_p    = 32
   ,parameter addr_width_p    = 30
   ,parameter tile_id_ptr_p   = -1
   ,parameter num_rows_p      = -1
   ,parameter num_cols_p      = -1
   ,parameter load_rows_p     = num_rows_p
   ,parameter load_cols_p     = num_cols_p

   ,parameter y_cord_width_lp  = `BSG_SAFE_CLOG2(num_rows_p + 1)
   ,parameter x_cord_width_lp  = `BSG_SAFE_CLOG2(num_cols_p)
   ,parameter packet_width_lp = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp)
  )
  ( input                        clk_i
   ,input                        reset_i
   ,output [packet_width_lp-1:0] data_o
   ,output                       v_o
   ,input                        ready_i

   ,input [data_width_p-1:0]     data_i
   ,output[addr_width_p-1:0]     addr_o

   ,input [y_cord_width_lp-1:0]  my_y_i
   ,input [x_cord_width_lp-1:0]  my_x_i
  );


  localparam tile_no_width_lp = 10;
  localparam tile_no_total_lp = load_rows_p * load_cols_p;

  logic [tile_no_width_lp-1:0]    tile_no, tile_no_n; // tile number is limited to 1023
  logic [addr_width_p-1:0]    load_addr;
  logic [data_width_p-1:0]    load_data;
  logic [y_cord_width_lp-1:0]  y_cord;
  logic [x_cord_width_lp-1:0]  x_cord;

  // after hexfile loading is complete packets with
  // opcode = 2 are sent to clear stall registers of tiles
  logic loaded, loaded_n; // set if hexfile loading is complete

  /************************************************************/
  // logic for config the arbiter
  logic         unfreezed_r;     // set if the cores are all unfreezed
  logic         arb_configed_r;
  localparam    arb_cfg_value = 0;
  localparam    config_addr_bits = 1 << ( addr_width_p-1);

  localparam    arb_cfg_addr  = addr_width_p'(4) | config_addr_bits;
  localparam    unfreeze_addr = addr_width_p'(0) | config_addr_bits;
  /************************************************************/

  assign load_data = loaded                       ? data_width_p'(0)            :
                     (unfreezed_r               ) ? data_width_p'(arb_cfg_value):
                     (load_addr == tile_id_ptr_p) ? data_width_p'(tile_no)      : data_i;

  assign y_cord     = y_cord_width_lp'(tile_no / num_cols_p);
  assign x_cord     = x_cord_width_lp'(tile_no % num_cols_p);

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp);

   bsg_manycore_packet_s pkt;

   logic [addr_width_p-1:0]    send_addr;
   assign send_addr = loaded         ? unfreeze_addr  :
                      unfreezed_r    ? arb_cfg_addr   : addr_width_p'(load_addr>>2)  ;
   always_comb
     begin
        pkt.data   = load_data;
        pkt.addr   = send_addr;
        pkt.op     = `ePacketOp_remote_store;
        pkt.op_ex  = loaded ? 4'b0000: 4'b1111;
        pkt.x_cord = x_cord;
        pkt.y_cord = y_cord;
        pkt.src_x_cord = my_x_i;
        pkt.src_y_cord = my_y_i;
     end

   assign data_o = pkt;

`ifndef BSG_HETERO_TYPE_VEC
`define BSG_HETERO_TYPE_VEC 0
`endif

   assign v_o  = ~reset_i
                 // & (~unfreezed_r | ( unfreezed_r && (tile_no < load_rows_p*load_cols_p)))
               `ifdef SHUT_DY_ARB
                 & (~arb_configed_r)
               `else
                 & (~unfreezed_r )
               `endif
                 // for now, we override sending the program if the core is an accelerator core
                 & (((`BSG_HETERO_TYPE_VEC >> (tile_no<<3)) & 8'b1111_1111) < 3);
                   ;

   assign addr_o   = addr_width_p'(load_addr >> 2);

   wire tile_loading_done = (load_addr == (mem_size_p-4));

   //assign tile_no_n = (tile_no + tile_loading_done)  % (load_rows_p * load_cols_p);
   wire [tile_no_width_lp-1:0]  tile_no_plus_done= tile_no  + tile_loading_done;
   assign tile_no_n = (tile_no_plus_done == tile_no_total_lp) ? 0 : tile_no_plus_done ;


   assign loaded_n = (tile_no == load_rows_p*load_cols_p -1)
                  && (load_addr == (mem_size_p-4));

  always_ff @(negedge clk_i)
    if (reset_i===0 && ~loaded && ready_i)
      begin
         if ((load_addr & 12'hFFF) == 0)
           $display("Loader: Tile %d, Addr %x (%m)",tile_no, load_addr);
         if (loaded_n)
           $display("Finished loading. (%m)");
      end

  always_ff @(posedge clk_i)
  begin
    if(reset_i)
      begin
        tile_no   <= 0;
        load_addr <= 0;
        loaded    <= 0;
        unfreezed_r<= 0;
        arb_configed_r <=0;
      end
    else
      begin
        if(ready_i & ~loaded) begin
             load_addr <= (load_addr + 4) % mem_size_p;
             tile_no   <= tile_no_n;
             loaded    <= loaded_n;
        end else if(ready_i & ( loaded | unfreezed_r ) ) begin
          if( unfreezed_r ) begin
                tile_no <=  tile_no + 1;
          end else
                //tile_no <= ( tile_no + 1 ) % ( load_rows_p*load_cols_p );
                tile_no <= ( (tile_no + 1) == tile_no_total_lp) ?  0 : tile_no + 1;
        end

        if(ready_i &&  loaded &&  tile_no ==  (load_rows_p * load_cols_p-1) )
          unfreezed_r <= 1'b1;

        if(ready_i && unfreezed_r  &&  tile_no ==  (load_rows_p * load_cols_p-1) )
          arb_configed_r<= 1'b1;

      end
  end
endmodule
