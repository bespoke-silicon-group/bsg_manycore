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
             $fwrite(1,"x=%x y=%x PC_IF=%4.4x imem_wait=%x dmem_wait=%x dmem_en=%x exception_code_WB=%x imem_addr=%x imem_data=%x replay_IF=%x stall_IF=%x stall_DX "
                     ,my_x_i, my_y_i,PC_IF,imem_wait,dmem_wait,dmem_en,exception_code_WB, imem_addr, imem_rdata, ctrl.replay_IF, ctrl.stall_IF, ctrl.stall_DX);
             if (wr_reg_WB & ~stall_WB & (reg_to_wr_WB != 0))
               $fwrite(1,"r[%2.2x]=%x ",reg_to_wr_WB,wb_data_WB);
             $fwrite(1,"\n");
          end
     end
endmodule

module bsg_manycore_tile_trace #(packet_width_lp="inv"
                                 ,return_packet_width_lp="inv"
                                 ,x_cord_width_p="inv"
                                 ,y_cord_width_p="inv"
                                 ,addr_width_p="inv"
                                 ,data_width_p="inv"
                                 ,dirs_lp=4
                                 ,num_nets_lp=2)
   (input clk_i
    , input [dirs_lp-1:0][packet_width_lp-1:0] data_o
    , input [dirs_lp-1:0][return_packet_width_lp-1:0] return_data_o
    , input [num_nets_lp-1:0][dirs_lp-1:0] ready_i
    , input [num_nets_lp-1:0][dirs_lp-1:0] v_o
    , input [num_nets_lp-1:0][dirs_lp-1:0] v_i
    , input [dirs_lp-1:0][packet_width_lp-1:0] data_i
    , input [dirs_lp-1:0][return_packet_width_lp-1:0] return_data_i
    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
    , input freeze
    );

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   bsg_manycore_packet_s [dirs_lp-1:0] pkt;
   bsg_manycore_return_packet_s [dirs_lp-1:0] return_pkt;

   assign pkt        = data_o;
   assign return_pkt = return_data_o;

   genvar i;

//   if (0)
   always @(negedge clk_i)
     begin
        if ( ~freeze &  (|(ready_i & v_o)))
          begin
             $fwrite(1,"%x ", test_bsg_manycore.cycle_count);
             $fwrite(1,"YX=%x,%x r ", my_y_i,my_x_i);
             if (v_o[0][0] & ready_i[0][0])
               $fwrite(1,"W<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}"
		       ,pkt[0].op,pkt[0].addr,pkt[0].data, pkt[0].return_pkt.y_cord, pkt[0].return_pkt.x_cord, pkt[0].y_cord,pkt[0].x_cord);
             if (v_o[0][1] & ready_i[0][1])
               $fwrite(1,"E<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}",pkt[1].op,pkt[1].addr,pkt[1].data, pkt[1].return_pkt.y_cord, pkt[1].return_pkt.x_cord,pkt[1].y_cord,pkt[1].x_cord);
             if (v_o[0][2] & ready_i[0][2])
               $fwrite(1,"N<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}",pkt[2].op,pkt[2].addr,pkt[2].data, pkt[2].return_pkt.y_cord, pkt[2].return_pkt.x_cord, pkt[2].y_cord,pkt[2].x_cord);
             if (v_o[0][3] & ready_i[0][3])
               $fwrite(1,"S<-{%1.1x,%8.8x,%8.8x,YX={%x,%x->%x,%x}}",pkt[3].op,pkt[3].addr,pkt[3].data, pkt[3].return_pkt.y_cord, pkt[3].return_pkt.x_cord, pkt[3].y_cord,pkt[3].x_cord);

             if (v_o[1][0] & ready_i[1][0])
               $fwrite(1,"W<-c YX={%x,%x}", return_pkt[0].y_cord, return_pkt[0].x_cord);
             if (v_o[1][1] & ready_i[1][1])
               $fwrite(1,"E<-c YX={%x,%x}", return_pkt[1].y_cord, return_pkt[1].x_cord);
             if (v_o[1][2] & ready_i[1][2])
               $fwrite(1,"N<-c YX={%x,%x}", return_pkt[2].y_cord, return_pkt[2].x_cord);
             if (v_o[1][3] & ready_i[1][3])
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
   , input [num_nets_lp-1:0]            v_out
   , input [num_nets_lp-1:0]            ready_in
   , input [packet_width_lp-1:0]        data_out
   , input [return_packet_width_lp-1:0] return_data_out
   , input [num_nets_lp-1:0]            v_in
   , input [num_nets_lp-1:0]            ready_out
   , input [packet_width_lp-1:0]        data_in
   , input [return_packet_width_lp-1:0] return_data_in
   , input freeze_r
   , input cgni_v_in
   , input [packet_width_lp-1:0] cgni_data_in
   );

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

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

        if (~freeze_r & ((|logwrite)| (|v_in) | (|v_out) | (|conflicts)))
          begin
             $fwrite(1,"%x ", test_bsg_manycore.cycle_count);
             $fwrite(1,"YX=%x,%x %b %b %b %x ", my_y_i,my_x_i, ready_in, ready_out, cgni_v_in, cgni_data_in);

             if (logwrite[0])
               $fwrite(1,"D%1.1x[%x,%b]=%x, ", 1,{ xbar_port_addr_in[1],2'b00},xbar_port_mask_in[1],xbar_port_data_in[1]);

             if (logwrite[1])
               $fwrite(1,"D%1.1x[%x,%b]=%x, ", 2,{ xbar_port_addr_in[2],2'b00},xbar_port_mask_in[2],xbar_port_data_in[2]);

             if (~|logwrite)
               $fwrite(1,"                   ");

             packets        = {       data_in,        data_out};
             return_packets = {return_data_in, return_data_out};

             if (v_in[0])
               $fwrite(1,"<-{%2.2b,%4.4b %8.8x,%8.8x,YX={%x,%x->%x,%x}} "
                       ,packets[1].op,packets[1].op_ex,packets[1].addr,packets[1].data, packets[1].return_pkt.y_cord, packets[1].return_pkt.x_cord, packets[1].y_cord,packets[1].x_cord);

             if (v_out[0])
               $fwrite(1,"->{%2.2b,%4.4b %8.8x,%8.8x,YX={%x,%x->%x,%x}} "
                       ,packets[0].op,packets[0].op_ex,packets[0].addr,packets[0].data,  packets[0].return_pkt.y_cord, packets[0].return_pkt.x_cord, packets[0].y_cord,packets[0].x_cord);

             if (v_in[1])
               $fwrite(1,"<-c(YX=%x,%x) ",return_packets[1].y_cord, return_packets[1].x_cord);

             if (v_out[1])
               $fwrite(1,"->c(YX=%x,%x) ",return_packets[0].y_cord, return_packets[0].x_cord);

             // detect bank conflicts

             if (|conflicts)
               $fwrite(1,"C%b",conflicts);

             $fwrite(1,"\n");
          end // if (xbar_port_yumi_out[1]...
     end
endmodule


module test_bsg_manycore;

   import  bsg_noc_pkg   ::*; // {P=0, W, E, N, S}

   localparam debug_lp = 0;
   localparam max_cycles_lp   = `MAX_CYCLES;
   localparam tile_id_ptr_lp  = -1;
   localparam mem_size_lp     = `MEM_SIZE;  // actually the size of the file being loaded, in bytes
   localparam bank_size_lp    = `BANK_SIZE;   // in 32-bit words
   localparam num_banks_lp    = `BANK_NUM;
   localparam data_width_lp   = 32;
   localparam addr_width_lp   = 32;
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
                                                       ) bmtt
       (.clk_i
        ,.data_o
        ,.return_data_o
        ,.ready_i
        ,.v_o
        ,.v_i
        ,.data_i
        ,.return_data_i
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
        ,v_o
        ,ready_i
        ,data_o
        ,return_data_o
        ,v_i
        ,ready_o
        ,data_i
        ,return_data_i
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

  logic [addr_width_lp-1:0]   mem_addr;
  logic [data_width_lp-1:0]   mem_data;

  logic [packet_width_lp-1:0] test_data_in;
  logic                       test_v_in;

  logic [S:N][num_tiles_x_lp-1:0][num_nets_lp-1:0]     ver_v_in,     ver_v_out;
  logic [S:N][num_tiles_x_lp-1:0][num_nets_lp-1:0]     ver_ready_in, ver_ready_out;

  logic [S:N][num_tiles_x_lp-1:0][packet_width_lp-1:0] ver_data_in,  ver_data_out;
  logic [E:W][num_tiles_y_lp-1:0][packet_width_lp-1:0] hor_data_in,  hor_data_out;

  logic [S:N][num_tiles_x_lp-1:0][return_packet_width_lp-1:0] ver_return_data_in,  ver_return_data_out;
  logic [E:W][num_tiles_y_lp-1:0][return_packet_width_lp-1:0] hor_return_data_in,  hor_return_data_out;

  logic [E:W][num_tiles_y_lp-1:0][num_nets_lp-1:0]     hor_v_in, hor_v_out;
  logic [E:W][num_tiles_y_lp-1:0][num_nets_lp-1:0]     hor_ready_in, hor_ready_out;

  bsg_manycore #
    (
     .bank_size_p  (bank_size_lp)
     ,.num_banks_p (num_banks_lp)
     ,.data_width_p (data_width_lp)
     ,.addr_width_p (addr_width_lp)
     ,.num_tiles_x_p(num_tiles_x_lp)
     ,.num_tiles_y_p(num_tiles_y_lp)
     ,.stub_w_p     ({{(num_tiles_y_lp-1){1'b1}}, 1'b0})
     ,.stub_e_p     ({num_tiles_y_lp{1'b1}})
     ,.stub_n_p     ({num_tiles_x_lp{1'b1}}) // loads through N-side of (0,0)
      // ,.stub_s_p     ({num_tiles_x_lp{1'b1}})
      // no stubs for south side
     ,.stub_s_p     ({num_tiles_x_lp{1'b0}})
     ,.debug_p(debug_lp)
    ) UUT
      ( .clk_i   (clk)
        ,.reset_i (reset)

        ,.ver_data_i        (ver_data_in        )
        ,.ver_return_data_i (ver_return_data_in )
        ,.ver_v_i           (ver_v_in           )
        ,.ver_ready_o       (ver_ready_out      )

        ,.ver_data_o        (ver_data_out       )
        ,.ver_return_data_o (ver_return_data_out)
        ,.ver_v_o           (ver_v_out          )
        ,.ver_ready_i       (ver_ready_in       )

        ,.hor_data_i        (hor_data_in        )
        ,.hor_return_data_i (hor_return_data_in )
        ,.hor_v_i           (hor_v_in           )
        ,.hor_ready_o       (hor_ready_out      )

        ,.hor_data_o        (hor_data_out       )
        ,.hor_return_data_o (hor_return_data_out)
        ,.hor_v_o           (hor_v_out          )
        ,.hor_ready_i       (hor_ready_in       )
        );

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
            freeze_r <= UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.freeze;

          always @(negedge clk)
            begin
               if (freeze_r & ~UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.freeze)
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
                    if (min_store_credits[x][y] > UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.remote_store_credits)
                      min_store_credits[x][y] <= UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.remote_store_credits;

                    if (UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.imem_wait)
                      imem_stalls[x][y] <= imem_stalls[x][y]+1;
                    if (UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.dmem_wait
                        & UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.dmem_en)
                      dmem_stalls[x][y] <= dmem_stalls[x][y]+1;
                    else if (UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.ctrl.dmem_reserve_acq_stall)
                      rsrv_stalls[x][y] <= rsrv_stalls[x][y]+1;
                    else if (UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.ctrl.stall_DX_premem)
                      dx_stalls[x][y] <= dx_stalls[x][y]+1;
                    else if (UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.ctrl.redirect)
                      redirect_stalls[x][y] <= redirect_stalls[x][y]+1;
                    if (~UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.ready_o[0])
                      cgni_full_cycles[x][y] <= cgni_full_cycles[x][y]+1;
                    if (~UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.ready_i[0])
                      cgno_full_cycles[x][y] <= cgno_full_cycles[x][y]+1;
                    if (~UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.ready_i[1])
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
                             ,x,y,UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.csr.instret_full, non_frozen_cycles[x][y],dmem_stalls[x][y],imem_stalls[x][y],dx_stalls[x][y],redirect_stalls[x][y],rsrv_stalls[x][y],cgni_full_cycles[x][y],cgno_full_cycles[x][y],cgno_credit_full_cycles[x][y]);
                    $display("##                         %-2.1f%%        %-2.1f%%       %-2.1f%%       %-2.1f%%       %-2.1f%%      %-2.1f%%       %-2.1f%%       %-2.1f%%     %-2.1f%%"
                             , 100.0 * ((real' (non_frozen_cycles[x][y]) / (real' (UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.core.vscale.csr.instret_full))))
                             , 100.0 * ((real' (dmem_stalls      [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (imem_stalls      [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (dx_stalls        [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (redirect_stalls  [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (rsrv_stalls      [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (cgni_full_cycles [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (cgno_full_cycles [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             , 100.0 * ((real' (cgno_credit_full_cycles [x][y]) / (real' (non_frozen_cycles[x][y]))))
                             );
                    $display("##        minimum store credits: %d / %d ", min_store_credits[x][y], UUT.tile_row_gen[y].tile_col_gen[x].tile.proc.max_remote_store_credits_p);

                    if (x == num_tiles_x_lp-1 && y == num_tiles_y_lp-1)
                      $display("##\n");
                 end
            end // always @ (negedge clk)
       end

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
       ,.data_o   (test_data_in)
       ,.v_o      (test_v_in)
       ,.ready_i  (hor_ready_out[W][0][0])
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

   // only North side needs to be tied off; south side is connected to manycore monitor
   assign ver_data_in       [N] = (num_tiles_x_lp*packet_width_lp)'(0);
   assign ver_return_data_in[N] = (num_tiles_x_lp*return_packet_width_lp)'(0);
   assign ver_v_in          [N] = (num_nets_lp*num_tiles_x_lp)'(0);

   // absorb all outgoing packets
   assign ver_ready_in      [N] = { (num_nets_lp*num_tiles_x_lp) {1'b1} };

   assign hor_data_in        = (2*num_tiles_y_lp*packet_width_lp)'(0) | test_data_in;
   assign hor_return_data_in = (2*num_tiles_y_lp*packet_width_lp)'(0);
   assign hor_v_in           = (2*num_nets_lp*num_tiles_y_lp)'(0)     | test_v_in;

   // absorb all outgoing packets
   assign hor_ready_in       = { (2*num_nets_lp*num_tiles_y_lp) {1'b1}};

   wire [39:0] cycle_count;

   bsg_cycle_counter #(.width_p(40),.init_val_p(0))
   cc (.clk(clk), .reset_i(reset), .ctr_r_o(cycle_count));

   wire [num_tiles_x_lp-1:0] finish_lo_vec;

   assign finish_lo = | finish_lo_vec;

   genvar 		    i;
   
   for (i = 0; i < num_tiles_x_lp; i=i+1)
     begin: rof
        bsg_nonsynth_manycore_monitor #(.x_cord_width_p (lg_node_x_lp)
                                        ,.y_cord_width_p(lg_node_y_lp)
                                        ,.addr_width_p  (addr_width_lp)
                                        ,.data_width_p  (data_width_lp)
                                        ,.channel_num_p (i)
                                        ,.max_cycles_p(max_cycles_lp)
                                        ) bmm (.clk_i(clk)
                                               ,.reset_i (reset)

                                               ,.v_i          (ver_v_out          [S][i])
                                               ,.data_i       (ver_data_out       [S][i])
                                               ,.return_data_i(ver_return_data_out[S][i])
                                               ,.ready_o      (ver_ready_in       [S][i])

                                               ,.v_o          (ver_v_in           [S][i])
                                               ,.data_o       (ver_data_in        [S][i])
                                               ,.return_data_o(ver_return_data_in [S][i])
                                               ,.ready_i      (ver_ready_out      [S][i])
                                               ,.cycle_count_i(cycle_count)
                                               ,.finish_o     (finish_lo_vec[i])
                                               );
     end

endmodule
