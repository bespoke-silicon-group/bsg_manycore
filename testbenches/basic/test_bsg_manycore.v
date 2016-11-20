`include "bsg_manycore_packet.vh"


`define SPMD       ????             // test program to be loaded
`define ROM(spmd)  bsg_rom_``spmd`` // ROM contaning the spmd
`define BANK_SIZE  1024   // in words
`define BANK_NUM   1
`define IMEM_SIZE  1024   // in words
 //The total memory size, which is used for ROM loader
`define MEM_SIZE   ( `BANK_NUM*`BANK_SIZE*4  +  `IMEM_SIZE * 4)

`ifndef bsg_tiles_X
`error bsg_tiles_X must be defined; pass it in through the makefile
`endif

`ifndef bsg_tiles_Y
`error bsg_tiles_Y must be defined; pass it in through the makefile
`endif

`define MAX_CYCLES 1000000




`ifdef ENABLE_TRACE
`endif  // TRACE

module test_bsg_manycore;

   import  bsg_noc_pkg   ::*; // {P=0, W, E, N, S}

   localparam debug_lp = 0;
   localparam max_cycles_lp   = `MAX_CYCLES;
   localparam tile_id_ptr_lp  = -1;
   localparam mem_size_lp     = `MEM_SIZE;  // actually the size of the file being loaded, in bytes
   localparam imem_size_lp    = `IMEM_SIZE;
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
     bind   vscale_pipeline bsg_manycore_vscale_pipeline_trace #(.x_cord_width_p(x_cord_width_p)
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

`ifndef BSG_HETERO_TYPE_VEC
`define BSG_HETERO_TYPE_VEC 0
`endif

  bsg_manycore #
    (
     .bank_size_p  (bank_size_lp)
     ,.imem_size_p (imem_size_lp)
     ,.num_banks_p (num_banks_lp)
     ,.data_width_p (data_width_lp)
     ,.addr_width_p (addr_width_lp)
     ,.num_tiles_x_p(num_tiles_x_lp)
     ,.num_tiles_y_p(num_tiles_y_lp)
     ,.hetero_type_vec_p(`BSG_HETERO_TYPE_VEC)
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


   for (i = 0; i < num_tiles_x_lp; i=i+1)
     begin: rof
        // tie off north side; which is inaccessible
        bsg_manycore_link_sif_tieoff #(.addr_width_p   (addr_width_lp)
                                       ,.data_width_p  (data_width_lp)
                                       ,.x_cord_width_p(lg_node_x_lp)
                                       ,.y_cord_width_p(lg_node_y_lp)
                                       ) bmlst3
        (.clk_i(clk)
         ,.reset_i(reset)
         ,.link_sif_i(ver_link_lo[N][i])
         ,.link_sif_o(ver_link_li[N][i])
         );
     end


   bsg_nonsynth_manycore_io_complex
     #( .mem_size_p  (mem_size_lp)
        ,.addr_width_p(addr_width_lp)
        ,.data_width_p(data_width_lp)
	,.max_cycles_p(max_cycles_lp)
        ,.num_tiles_x_p(num_tiles_x_lp)
        ,.num_tiles_y_p(num_tiles_y_lp)
	,.tile_id_ptr_p(tile_id_ptr_lp)
        ) io
   (.clk_i(clk)
    ,.reset_i(reset)
    ,.ver_link_sif_i(ver_link_lo[S])
    ,.ver_link_sif_o(ver_link_li[S])
    );


endmodule
