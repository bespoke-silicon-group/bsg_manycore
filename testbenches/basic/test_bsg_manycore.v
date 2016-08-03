`include "bsg_manycore_packet.vh"


`define SPMD       ????             // test program to be loaded
`define ROM(spmd)  bsg_rom_``spmd`` // ROM contaning the spmd
`define MEM_SIZE   32768
`define BANK_SIZE  1024   // in words
`define BANK_NUM   8
//`define BANK_SIZE  2048   // in words
//`define BANK_NUM   4

`ifndef bsg_tiles_X
`error bsg_tiles_X must be defined; pass it in through the makefile
`endif

`ifndef bsg_tiles_Y
`error bsg_tiles_Y must be defined; pass it in through the makefile
`endif

`define MAX_CYCLES 1000000

  module vscale_pipeline_trace
      #(parameter x_cord_width_p = "inv"
        , y_cord_width_p = "inv")
 (input clk_i
  , input [31:0] PC_IF
  , input wr_reg_WB
  , input [4:0] reg_to_wr_WB
  , input [31:0] wb_data_WB
  , input stall_WB
  , input imem_wait
  , input dmem_wait
  , input dmem_en
  , input [3:0] exception_code_WB
  , input [31:0] imem_addr
  , input [31:0] imem_rdata
  , input freeze
   ,input   [x_cord_width_p-1:0] my_x_i
   ,input   [y_cord_width_p-1:0] my_y_i
  );

   always @(negedge clk_i)
     begin
        if (~freeze)
          begin
             $fwrite(1,"x=%x y=%x PC_IF=%4.4x imem_wait=%x dmem_wait=%x dmem_en=%x exception_code_WB=%x imem_addr=%x imem_data=%x replay_IF=%x stall_IF=%x stall_DX=%x "
                     ,my_x_i, my_y_i,PC_IF,imem_wait,dmem_wait,dmem_en,exception_code_WB, imem_addr, imem_rdata, ctrl.replay_IF, ctrl.stall_IF, ctrl.stall_DX);
             if (wr_reg_WB & ~stall_WB & (reg_to_wr_WB != 0))
               $fwrite(1,"r[%2.2x]=%x ",reg_to_wr_WB,wb_data_WB);
             $fwrite(1,"\n");
          end
     end
endmodule



module bsg_manycore_tile_trace #(bsg_manycore_link_sif_width_lp="inv"
                                 ,packet_width_lp="inv"
                                 ,return_packet_width_lp="inv"
                                 ,x_cord_width_p="inv"
                                 ,y_cord_width_p="inv"
                                 ,addr_width_p="inv"
                                 ,data_width_p="inv"
                                 ,dirs_lp=4
                                 ,num_nets_lp=2)
   (input clk_i
    , input  [dirs_lp-1:0][bsg_manycore_link_sif_width_lp-1:0] links_sif_i
    , input [dirs_lp-1:0][bsg_manycore_link_sif_width_lp-1:0] links_sif_o
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
    , input freeze
    );

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
   `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   bsg_manycore_link_sif_s [dirs_lp-1:0] links_sif_i_cast, links_sif_o_cast;

   bsg_manycore_packet_s [dirs_lp-1:0] pkt;
   bsg_manycore_return_packet_s [dirs_lp-1:0] return_pkt;

   assign links_sif_i_cast = links_sif_i;
   assign links_sif_o_cast = links_sif_o;

   genvar i;

   logic [dirs_lp-1:0] activity;

   for (i = 0; i < dirs_lp; i=i+1)
     begin : rof2
        assign pkt[i]        = links_sif_o_cast[i].fwd.data;
        assign return_pkt[i] = links_sif_o_cast[i].rev.data;
        assign activity  [i] = (links_sif_o_cast[i].fwd.v & links_sif_i_cast[i].fwd.v)
                              |(links_sif_o_cast[i].rev.v & links_sif_i_cast[i].rev.v);
     end


//   if (0)
   always @(negedge clk_i)
     begin
//        if ( ~freeze &  (|activity))
        if (1)
          begin
             $fwrite(1,"%x ", test_bsg_manycore.cycle_count);
             $fwrite(1,"YX=%x,%x r ", my_y_i,my_x_i);
             $fwrite(1,"WENS vo=%b%b%b%b ri=%b%b%b%b vi=%b%b%b%b ro=%b%b%b%b "
                     ,links_sif_o_cast[0].fwd.v
                     ,links_sif_o_cast[1].fwd.v
                     ,links_sif_o_cast[2].fwd.v
                     ,links_sif_o_cast[3].fwd.v

                     ,links_sif_i_cast[0].fwd.ready_and_rev
                     ,links_sif_i_cast[1].fwd.ready_and_rev
                     ,links_sif_i_cast[2].fwd.ready_and_rev
                     ,links_sif_i_cast[3].fwd.ready_and_rev

                     ,links_sif_i_cast[0].fwd.v
                     ,links_sif_i_cast[1].fwd.v
                     ,links_sif_i_cast[2].fwd.v
                     ,links_sif_i_cast[3].fwd.v

                     ,links_sif_o_cast[0].fwd.ready_and_rev
                     ,links_sif_o_cast[1].fwd.ready_and_rev
                     ,links_sif_o_cast[2].fwd.ready_and_rev
                     ,links_sif_o_cast[3].fwd.ready_and_rev

                     );
//             if (links_sif_o_cast[0].fwd.v & links_sif_i_cast[0].fwd.ready_and_rev)
               $fwrite(1,"W<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}"
                       ,pkt[0].op,pkt[0].addr,pkt[0].data, pkt[0].return_pkt.y_cord, pkt[0].return_pkt.x_cord, pkt[0].y_cord,pkt[0].x_cord);
//             if (links_sif_o_cast[1].fwd.v & links_sif_i_cast[1].fwd.ready_and_rev)
               $fwrite(1,"E<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}",pkt[1].op,pkt[1].addr,pkt[1].data, pkt[1].return_pkt.y_cord, pkt[1].return_pkt.x_cord,pkt[1].y_cord,pkt[1].x_cord);
//             if (links_sif_o_cast[2].fwd.v & links_sif_i_cast[2].fwd.ready_and_rev)
               $fwrite(1,"N<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}",pkt[2].op,pkt[2].addr,pkt[2].data, pkt[2].return_pkt.y_cord, pkt[2].return_pkt.x_cord, pkt[2].y_cord,pkt[2].x_cord);
//             if (links_sif_o_cast[3].fwd.v & links_sif_i_cast[3].fwd.ready_and_rev)
               $fwrite(1,"S<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}",pkt[3].op,pkt[3].addr,pkt[3].data, pkt[3].return_pkt.y_cord, pkt[3].return_pkt.x_cord, pkt[3].y_cord,pkt[3].x_cord);

//             if (links_sif_o_cast[0].rev.v & links_sif_i_cast[0].rev.ready_and_rev)
               $fwrite(1,"W<-c YX={%x,%x}", return_pkt[0].y_cord, return_pkt[0].x_cord);
//             if (links_sif_o_cast[1].rev.v & links_sif_i_cast[1].rev.ready_and_rev)
               $fwrite(1,"E<-c YX={%x,%x}", return_pkt[1].y_cord, return_pkt[1].x_cord);
//             if (links_sif_o_cast[2].rev.v & links_sif_i_cast[2].rev.ready_and_rev)
               $fwrite(1,"N<-c YX={%x,%x}", return_pkt[2].y_cord, return_pkt[2].x_cord);
//             if (links_sif_o_cast[3].rev.v & links_sif_i_cast[3].rev.ready_and_rev)
               $fwrite(1,"S<-c YX={%x,%x}", return_pkt[3].y_cord, return_pkt[3].x_cord);

             $fwrite(1,"\n");

          end
     end
endmodule



module bsg_manycore_proc_trace #(parameter mem_width_lp=-1
                                 , data_width_p=-1
                                 , addr_width_p="inv"
                                 , x_cord_width_p="inv"
                                 , y_cord_width_p="inv"
                                 , packet_width_lp="inv"
                                 , return_packet_width_lp="inv"
                                 , bsg_manycore_link_sif_width_lp="inv"
                                 , num_nets_lp=2
                                 )
  (input clk_i
   , input [2:0] xbar_port_v_in
   , input [2:0][mem_width_lp-1:0] xbar_port_addr_in
   , input [2:0][data_width_p-1:0] xbar_port_data_in
   , input [2:0][(data_width_p>>3)-1:0] xbar_port_mask_in
   , input [2:0] xbar_port_we_in
   , input [2:0] xbar_port_yumi_out
   , input [x_cord_width_p-1:0] my_x_i
   , input [y_cord_width_p-1:0] my_y_i

   , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
   , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

   , input freeze_r
   , input cgni_v_in
   , input [packet_width_lp-1:0] cgni_data_in
   );

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
   bsg_manycore_link_sif_s link_sif_i_cast, link_sif_o_cast;

   assign link_sif_i_cast = link_sif_i;
   assign link_sif_o_cast = link_sif_o;

   bsg_manycore_packet_s [1:0] packets;
   bsg_manycore_return_packet_s [1:0] return_packets;



   genvar i;

   logic [1:0] logwrite;
   logic [2:0] conflicts;

//   if (0)
   always @(negedge clk_i)
     begin
        logwrite = { (xbar_port_we_in[2] & xbar_port_yumi_out[2])
                     ,xbar_port_we_in[1] & xbar_port_yumi_out[1]
          };

        conflicts = xbar_port_yumi_out ^ xbar_port_v_in;

/*        if (~freeze_r & ((|logwrite)
             | link_sif_i_cast.fwd.v
             | link_sif_o_cast.fwd.v
             | link_sif_i_cast.rev.v
             | link_sif_o_cast.rev.v
             | (|conflicts))) */
          begin
             $fwrite(1,"%x ", test_bsg_manycore.cycle_count);
             $fwrite(1,"YX=%x,%x %b%b %b%b %b %x ", my_y_i,my_x_i
                     , link_sif_i_cast.fwd.ready_and_rev
                     , link_sif_o_cast.fwd.ready_and_rev
                     , link_sif_i_cast.rev.ready_and_rev
                     , link_sif_o_cast.rev.ready_and_rev
                     , cgni_v_in
                     , cgni_data_in);

             if (logwrite[0])
               $fwrite(1,"D%1.1x[%x,%b]=%x, ", 1,{ xbar_port_addr_in[1],2'b00},xbar_port_mask_in[1],xbar_port_data_in[1]);

             if (logwrite[1])
               $fwrite(1,"D%1.1x[%x,%b]=%x, ", 2,{ xbar_port_addr_in[2],2'b00},xbar_port_mask_in[2],xbar_port_data_in[2]);

             if (~|logwrite)
               $fwrite(1,"                   ");

             packets        = { link_sif_i_cast.fwd.data, link_sif_o_cast.fwd.data };
             return_packets = { link_sif_i_cast.rev.data, link_sif_o_cast.rev.data };

             if (link_sif_i_cast.fwd.v)
               $fwrite(1,"<-{%2.2b,%4.4b %8.8x,%8.8x,YX={%x,%x->%x,%x}} "
                       ,packets[1].op,packets[1].op_ex,packets[1].addr,packets[1].data, packets[1].return_pkt.y_cord, packets[1].return_pkt.x_cord, packets[1].y_cord,packets[1].x_cord);

             if (link_sif_o_cast.fwd.v)
               $fwrite(1,"->{%2.2b,%4.4b %8.8x,%8.8x,YX={%x,%x->%x,%x}} "
                       ,packets[0].op,packets[0].op_ex,packets[0].addr,packets[0].data,  packets[0].return_pkt.y_cord, packets[0].return_pkt.x_cord, packets[0].y_cord,packets[0].x_cord);

//             if (link_sif_i_cast.rev.v)
               $fwrite(1,"<-c(YX=%x,%x) ",return_packets[1].y_cord, return_packets[1].x_cord);

//             if (link_sif_o_cast.rev.v)
               $fwrite(1,"->c(YX=%x,%x) ",return_packets[0].y_cord, return_packets[0].x_cord);

             // detect bank conflicts

             if (|conflicts)
               $fwrite(1,"C%b",conflicts);

             $fwrite(1,"\n");
          end // if (xbar_port_yumi_out[1]...
     end
endmodule

`ifdef ENABLE_TRACE
`endif  // TRACE

module test_bsg_manycore;

   import  bsg_noc_pkg   ::*; // {P=0, W, E, N, S}

   localparam debug_lp = 0;
   localparam max_cycles_lp   = `MAX_CYCLES;
   localparam tile_id_ptr_lp  = -1;
   localparam mem_size_lp     = `MEM_SIZE;  // actually the size of the file being loaded, in bytes
   localparam bank_size_lp    = `BANK_SIZE;   // in 32-bit words
   localparam num_banks_lp    = `BANK_NUM;
   localparam data_width_lp   = 32;
   localparam addr_width_lp   = 20;
   localparam num_tiles_x_lp  = `bsg_tiles_X;
   localparam num_tiles_y_lp  = `bsg_tiles_Y;
   localparam lg_node_x_lp    = `BSG_SAFE_CLOG2(num_tiles_x_lp);
   localparam lg_node_y_lp    = `BSG_SAFE_CLOG2(num_tiles_y_lp + 1);
   localparam packet_width_lp        = `bsg_manycore_packet_width       (addr_width_lp, data_width_lp, lg_node_x_lp, lg_node_y_lp);
   localparam return_packet_width_lp = `bsg_manycore_return_packet_width(lg_node_x_lp, lg_node_y_lp);
   localparam cycle_time_lp   = 20;
   localparam trace_vscale_pipeline_lp=0;
   localparam trace_manycore_tile_lp=0;
   localparam trace_manycore_proc_lp=0;

   wire finish_lo;

   if (trace_manycore_tile_lp)
     bind bsg_manycore_tile  bsg_manycore_tile_trace #(.packet_width_lp(packet_width_lp)
                                                       ,.return_packet_width_lp(return_packet_width_lp)
                                                       ,.x_cord_width_p(x_cord_width_p)
                                                       ,.y_cord_width_p(y_cord_width_p)
                                                       ,.addr_width_p(addr_width_p)
                                                       ,.data_width_p(data_width_p)
                                                       ,.bsg_manycore_link_sif_width_lp(bsg_manycore_link_sif_width_lp)
                                                       ) bmtt
       (.clk_i
        ,.links_sif_i
        ,.links_sif_o
        ,.my_x_i
        ,.my_y_i
        ,.freeze(freeze)
        );

   if (trace_vscale_pipeline_lp)
     bind   vscale_pipeline vscale_pipeline_trace #(.x_cord_width_p(x_cord_width_p)
                                                    ,.y_cord_width_p(y_cord_width_p)
                                                    ) vscale_trace(clk
                                                                   ,PC_IF
                                                                   ,wr_reg_WB
                                                                   ,reg_to_wr_WB
                                                                   ,wb_data_WB
                                                                   ,stall_WB
                                                                   ,imem_wait
                                                                   ,dmem_wait
                                                                   ,dmem_en
                                                                   ,exception_code_WB
                                                                   ,imem_addr
                                                                   ,imem_rdata
                                                                   ,freeze
                                                                   ,my_x_i
                                                                   ,my_y_i
                                                                   );
   if (trace_manycore_proc_lp)
     bind bsg_manycore_proc bsg_manycore_proc_trace #(.mem_width_lp(mem_width_lp)
                                                      ,.data_width_p(data_width_p)
                                                      ,.addr_width_p(addr_width_p)
                                                      ,.x_cord_width_p(x_cord_width_p)
                                                      ,.y_cord_width_p(y_cord_width_p)
                                                      ,.packet_width_lp(packet_width_lp)
                                                      ,.return_packet_width_lp(return_packet_width_lp)
                                                      ,.bsg_manycore_link_sif_width_lp(bsg_manycore_link_sif_width_lp)
                                                      ) proc_trace
       (clk_i
        ,xbar_port_v_in
        ,xbar_port_addr_in
        ,xbar_port_data_in
        ,xbar_port_mask_in
        ,xbar_port_we_in
        ,xbar_port_yumi_out
        ,my_x_i
        ,my_y_i
        ,link_sif_i
        ,link_sif_o

        ,freeze_r
        ,cgni_v
        ,cgni_data
        );


   localparam num_nets_lp = 2;

  // clock and reset generation
  wire clk;
  wire reset;

  bsg_nonsynth_clock_gen #( .cycle_time_p(cycle_time_lp)
                          ) clock_gen
                          ( .o(clk)
                          );

  bsg_nonsynth_reset_gen #(  .num_clocks_p     (1)
                           , .reset_cycles_lo_p(1)
                           , .reset_cycles_hi_p(10)
                          )  reset_gen
                          (  .clk_i        (clk)
                           , .async_reset_o(reset)
                          );

  integer       stderr = 32'h80000002;

   `declare_bsg_manycore_link_sif_s(addr_width_lp, data_width_lp, lg_node_x_lp, lg_node_y_lp);

   bsg_manycore_link_sif_s [S:N][num_tiles_x_lp-1:0] ver_link_li, ver_link_lo;
   bsg_manycore_link_sif_s [E:W][num_tiles_y_lp-1:0] hor_link_li, hor_link_lo;

`define TOPLEVEL UUT.bm

  bsg_manycore #
    (
     .bank_size_p  (bank_size_lp)
     ,.num_banks_p (num_banks_lp)
     ,.data_width_p (data_width_lp)
     ,.addr_width_p (addr_width_lp)
     ,.num_tiles_x_p(num_tiles_x_lp)
     ,.num_tiles_y_p(num_tiles_y_lp)

     // currently west side is stubbed except for upper left tile
     ,.stub_w_p     ({{(num_tiles_y_lp-1){1'b1}}, 1'b0})
     ,.stub_e_p     ({num_tiles_y_lp{1'b1}})
     ,.stub_n_p     ({num_tiles_x_lp{1'b1}})

     // south side is unstubbed
     ,.stub_s_p     ({num_tiles_x_lp{1'b0}})
     ,.debug_p(debug_lp)
    ) UUT
      ( .clk_i   (clk)
        ,.reset_i (reset)

        ,.hor_link_sif_i(hor_link_li)
        ,.hor_link_sif_o(hor_link_lo)

        ,.ver_link_sif_i(ver_link_li)
        ,.ver_link_sif_o(ver_link_lo)

        );

`ifdef PERF_COUNT

   logic [num_tiles_x_lp-1:0][num_tiles_y_lp-1:0][31:0] imem_stalls;
   logic [num_tiles_x_lp-1:0][num_tiles_y_lp-1:0][31:0] dmem_stalls;
   logic [num_tiles_x_lp-1:0][num_tiles_y_lp-1:0][31:0] dx_stalls;
   logic [num_tiles_x_lp-1:0][num_tiles_y_lp-1:0][31:0] redirect_stalls;
   logic [num_tiles_x_lp-1:0][num_tiles_y_lp-1:0][31:0] rsrv_stalls;
   logic [num_tiles_x_lp-1:0][num_tiles_y_lp-1:0][31:0] cgni_full_cycles;
   logic [num_tiles_x_lp-1:0][num_tiles_y_lp-1:0][31:0] cgno_full_cycles;
   logic [num_tiles_x_lp-1:0][num_tiles_y_lp-1:0][31:0] non_frozen_cycles;
   logic [num_tiles_x_lp-1:0][num_tiles_y_lp-1:0][31:0] cgno_credit_full_cycles;
   logic [num_tiles_x_lp-1:0][num_tiles_y_lp-1:0][31:0] min_store_credits;

   genvar                                               x,y;

   for (x = 0; x < num_tiles_x_lp; x++)
     for (y = 0; y < num_tiles_y_lp; y++)
       begin : stats

          logic freeze_r;

          always @(negedge clk)
            freeze_r <= `TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.freeze;

          always @(negedge clk)
            begin
               if (freeze_r & ~`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.freeze)
                 begin
                    imem_stalls[x][y]       <= 0;
                    dmem_stalls[x][y]       <= 0;
                    dx_stalls[x][y]         <= 0;
                    redirect_stalls  [x][y] <= 0;
                    cgni_full_cycles [x][y]        <= 0;
                    cgno_full_cycles [x][y]        <= 0;
                    cgno_credit_full_cycles [x][y] <= 0;
                    non_frozen_cycles[x][y] <= 0;
                    rsrv_stalls[x][y]       <= 0;
                    min_store_credits[x][y] <= 10000000;
                end
               else
                 begin
                    if (min_store_credits[x][y] > `TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.remote_store_credits)
                      min_store_credits[x][y] <= `TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.remote_store_credits;

                    if (`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.imem_wait)
                      imem_stalls[x][y] <= imem_stalls[x][y]+1;
                    if (`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.dmem_wait
                        & `TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.dmem_en)
                      dmem_stalls[x][y] <= dmem_stalls[x][y]+1;
                    else if (`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.ctrl.dmem_reserve_acq_stall)
                      rsrv_stalls[x][y] <= rsrv_stalls[x][y]+1;
                    else if (`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.ctrl.stall_DX_premem)
                      dx_stalls[x][y] <= dx_stalls[x][y]+1;
                    else if (`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.ctrl.redirect)
                      redirect_stalls[x][y] <= redirect_stalls[x][y]+1;
                    if (~`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.ready_o[0])
                      cgni_full_cycles[x][y] <= cgni_full_cycles[x][y]+1;
                    if (~`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.ready_i[0])
                      cgno_full_cycles[x][y] <= cgno_full_cycles[x][y]+1;
                    if (~`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.ready_i[1])
                      cgno_credit_full_cycles[x][y] <= cgno_credit_full_cycles[x][y]+1;

                    non_frozen_cycles[x][y] <= non_frozen_cycles[x][y]+1;
                 end
               if (finish_lo)
                 begin
                    if (x == 0 && y == 0)
                      begin
                         $display("\n");
                         $display("## PERFORMANCE DATA ###################################################");
                         $display("##\n");
                         $display("## a. DMEM_stalls occur when writing to full network");
                         $display("## b. IMEM_stalls are bank conflicts with DMEM or remote_stores");
                         $display("## c. DX_stalls are bypass and load use stalls");
                         $display("## d. BT stalls are branch taken penalties");
                         $display("## e. cgni_full_cycles are cycles when processor input buffer is full");
                         $display("##      these are a result of remote_store/dmem bank conflicts and");
                         $display("##      indicate likely sources of network congestion");
                         $display("## f. cgno_full_cycles are cycles when processor output buffer is full");
                         $display("## g. rsrv stalls are stalls waiting on lr.w.acquire instructions");
                         $display("##    these are used for high-level flow-control");
                         $display("##   keep in mind that polling causes instruction count to vary\n");
                         $display("##                                                        stalls                               full_cycles\n##");
                         $display("##    X  Y     INSTRS     CYCLES |      DMEM       IMEM         DX         BT       RSRV |      CGNI       CGNO    Credit");
                         $display("##   -- --  --------- ---------- |---------- ---------- ---------- ---------- ---------- |  -------- ---------- ---------");
                      end

                    $display("##   %2.2d,%2.2d  %9.9d %d |%d %d %d %d %d |%d %d %d"
                             ,x,y,`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.csr.instret_full, non_frozen_cycles[x][y],dmem_stalls[x][y],imem_stalls[x][y],dx_stalls[x][y],redirect_stalls[x][y],rsrv_stalls[x][y],cgni_full_cycles[x][y],cgno_full_cycles[x][y],cgno_credit_full_cycles[x][y]);
                    $display("##                         %-2.1f%%        %-2.1f%%       %-2.1f%%       %-2.1f%%       %-2.1f%%      %-2.1f%%       %-2.1f%%       %-2.1f%%     %-2.1f%%"
                             , 100.0 * ((real' (non_frozen_cycles[x][y]) / (real' (`TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.csr.instret_full))))
                             , 100.0 * ((real' (dmem_stalls      [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (imem_stalls      [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (dx_stalls        [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (redirect_stalls  [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (rsrv_stalls      [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (cgni_full_cycles [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (cgno_full_cycles [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (cgno_credit_full_cycles [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             );
                    $display("##        minimum store credits: %d / %d ", min_store_credits[x][y], `TOPLEVEL.tile_row_gen[y].tile_col_gen[x].tile.proc.max_remote_store_credits_p);

                    if (x == num_tiles_x_lp-1 && y == num_tiles_y_lp-1)
                      $display("##\n");
                 end
            end // always @ (negedge clk)
       end

`endif

   wire [39:0] cycle_count;

   bsg_cycle_counter #(.width_p(40),.init_val_p(0))
   cc (.clk(clk), .reset_i(reset), .ctr_r_o(cycle_count));

   genvar                   i,j;

   for (i = 0; i < num_tiles_y_lp; i=i+1)
     begin: rof2

        bsg_manycore_link_sif_tieoff #(.addr_width_p   (addr_width_lp  )
                                       ,.data_width_p  (data_width_lp  )
                                       ,.x_cord_width_p(lg_node_x_lp)
                                       ,.y_cord_width_p(lg_node_y_lp)
                                       ) bmlst
        (.clk_i(clk)
         ,.reset_i(reset)
         ,.link_sif_i(hor_link_lo[W][i])
         ,.link_sif_o(hor_link_li[W][i])
         );

        bsg_manycore_link_sif_tieoff #(.addr_width_p   (addr_width_lp  )
                                       ,.data_width_p  (data_width_lp  )
                                       ,.x_cord_width_p(lg_node_x_lp   )
                                       ,.y_cord_width_p(lg_node_y_lp   )
                                       ) bmlst2
        (.clk_i(clk)
         ,.reset_i(reset)
         ,.link_sif_i(hor_link_lo[E][i])
         ,.link_sif_o(hor_link_li[E][i])
         );
     end


  logic [addr_width_lp-1:0]   mem_addr;
  logic [data_width_lp-1:0]   mem_data;

  logic [packet_width_lp-1:0] loader_data_lo;
  logic                       loader_v_lo;
  logic                       loader_ready_li;

   bsg_manycore_spmd_loader
     #( .mem_size_p    (mem_size_lp)
        ,.num_rows_p    (num_tiles_y_lp)
        ,.num_cols_p    (num_tiles_x_lp)
        // go viral booting
        //,.load_rows_p(1)
        //,.load_cols_p(1)

        ,.data_width_p  (data_width_lp)
        ,.addr_width_p  (addr_width_lp)
        ,.tile_id_ptr_p (tile_id_ptr_lp)
        ) spmd_loader
       ( .clk_i     (clk)
         ,.reset_i  (reset)
         ,.data_o   (loader_data_lo )
         ,.v_o      (loader_v_lo    )
         ,.ready_i  (loader_ready_li)
         ,.data_i   (mem_data)
         ,.addr_o   (mem_addr)
         );

   `ROM(`SPMD)
   #( .addr_width_p(addr_width_lp)
      ,.width_p     (data_width_lp)
      ) spmd_rom
     ( .addr_i (mem_addr)
       ,.data_o (mem_data)
       );

   wire [num_tiles_x_lp-1:0] finish_lo_vec;
   assign finish_lo = | finish_lo_vec;

   for (i = 0; i < num_tiles_x_lp; i=i+1)
     begin: rof
        bsg_manycore_link_sif_tieoff #(.addr_width_p   (addr_width_lp  )
                                       ,.data_width_p  (data_width_lp  )
                                       ,.x_cord_width_p(lg_node_x_lp)
                                       ,.y_cord_width_p(lg_node_y_lp)
                                       ) bmlst3
        (.clk_i(clk)
         ,.reset_i(reset)
         ,.link_sif_i(ver_link_lo[N][i])
         ,.link_sif_o(ver_link_li[N][i])
         );

        wire pass_thru_ready_lo;

        // hook up the ready signal if this is x==0, S
        if (i==0)
          assign loader_ready_li = pass_thru_ready_lo;

        bsg_nonsynth_manycore_monitor #(.x_cord_width_p (lg_node_x_lp)
                                        ,.y_cord_width_p(lg_node_y_lp)
                                        ,.addr_width_p  (addr_width_lp)
                                        ,.data_width_p  (data_width_lp)
                                        ,.channel_num_p (i)
                                        ,.max_cycles_p(max_cycles_lp)
                                        ,.pass_thru_p(i==0)
                                        ) bmm (.clk_i(clk)
                                               ,.reset_i (reset)
                                               ,.link_sif_i   (ver_link_lo[S][i])
                                               ,.link_sif_o   (ver_link_li[S][i])
                                               ,.pass_thru_data_i (loader_data_lo )
                                               ,.pass_thru_v_i    (loader_v_lo    )
                                               ,.pass_thru_ready_o(pass_thru_ready_lo)
                                               ,.cycle_count_i(cycle_count)
                                               ,.finish_o     (finish_lo_vec[i])
                                               );
     end


endmodule
