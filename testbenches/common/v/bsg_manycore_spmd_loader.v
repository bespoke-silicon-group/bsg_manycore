`include "bsg_manycore_packet.vh"

module bsg_manycore_spmd_loader

import  bsg_vscale_pkg::*  // vscale constants
       ,bsg_noc_pkg   ::*; // {P=0, W, E, N, S}

 #( parameter mem_size_p      = -1 // size of mem to be loaded  (bytes) (?)
   ,parameter data_width_p    = hdata_width_p
   ,parameter addr_width_p    = haddr_width_p
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
  );

  logic [63:0]                tile_no, tile_no_n; // tile number
  logic [addr_width_p-1:0]    load_addr;
  logic [data_width_p-1:0]    load_data;
  logic [y_cord_width_lp-1:0]  y_cord;
  logic [x_cord_width_lp-1:0]  x_cord;

  // after hexfile loading is complete packets with
  // opcode = 2 are sent to clear stall registers of tiles
  logic loaded, loaded_n; // set if hexfile loading is complete

  assign load_data = loaded
                     ? data_width_p'(0)
                     : (load_addr == tile_id_ptr_p)
                        ? data_width_p'(tile_no)
                        : data_i;

  assign y_cord     = y_cord_width_lp'(tile_no / num_cols_p);
  assign x_cord     = x_cord_width_lp'(tile_no % num_cols_p);

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp);

   bsg_manycore_packet_s pkt;

   always_comb
     begin
        pkt.data   = load_data;
        pkt.addr   = load_addr;
        pkt.op     = loaded ? 2'b10: 2'b01;
        pkt.op_ex  = loaded ? 4'b0000: 4'b1111;
        pkt.x_cord = x_cord;
        pkt.y_cord = y_cord;
        pkt.return_pkt.x_cord = 0;
        pkt.return_pkt.y_cord = num_rows_p;           // route to east (fixme: will screw up east edge's credit counter)
     end

   assign data_o = pkt;

   assign v_o  = ~reset_i & (~loaded | (loaded && (tile_no < load_rows_p*load_cols_p)));
   assign addr_o   = addr_width_p'(load_addr / (addr_width_p >> 3));

   assign tile_no_n = (tile_no + (load_addr == (mem_size_p-4))) % (load_rows_p * load_cols_p);
   assign loaded_n = (tile_no == load_rows_p*load_cols_p -1)
     && (load_addr == (mem_size_p-4));


  always_ff @(negedge clk_i)
    if (~loaded && ready_i)
      begin
         if ((load_addr & 12'hFFF) == 0)
           $display("Loader: Tile %d, Addr %x",tile_no, load_addr);
         if (loaded_n)
           $display("Finished loading.");
      end

  always_ff @(posedge clk_i)
  begin
    if(reset_i)
      begin
        tile_no   <= 0;
        load_addr <= 0;
        loaded    <= 0;
      end
    else
      begin
        if(ready_i & ~loaded)
          begin
             load_addr <= (load_addr + 4) % mem_size_p;
             tile_no   <= tile_no_n;
             loaded <= loaded_n;
          end

        if(ready_i & loaded)
          tile_no <= tile_no + 1;
      end
  end
endmodule
