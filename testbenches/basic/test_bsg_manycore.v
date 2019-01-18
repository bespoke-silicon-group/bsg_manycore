`include "bsg_manycore_packet.vh"

`define DMEM_SIZE       1024  //in words
`define ICACHE_ENTRIES  1024
`define DRAM_CH_SIZE    1024  //in words

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
   localparam dmem_size_lp    = `DMEM_SIZE ;
   localparam icache_entries_num_lp  = `ICACHE_ENTRIES;
   localparam dram_ch_addr_width_lp   =  19; // 2MB;
   localparam icache_tag_width_lp= 12;      // 16MB PC address 
   localparam data_width_lp   = 32;
   localparam addr_width_lp   = 20;
   localparam load_id_width_lp = 11;
   localparam epa_addr_width_lp       = 16;
   localparam num_tiles_x_lp  = `bsg_tiles_X;
   localparam num_tiles_y_lp  = `bsg_tiles_Y;
   localparam extra_io_rows_lp= 2;
   localparam num_routers_y_lp  = num_tiles_y_lp + extra_io_rows_lp -1;
   localparam lg_node_x_lp    = `BSG_SAFE_CLOG2(num_tiles_x_lp);
   localparam lg_node_y_lp    = `BSG_SAFE_CLOG2(num_tiles_y_lp + extra_io_rows_lp);
   localparam packet_width_lp        = `bsg_manycore_packet_width       (addr_width_lp, data_width_lp, lg_node_x_lp, lg_node_y_lp, load_id_width_lp);
   localparam return_packet_width_lp = `bsg_manycore_return_packet_width(lg_node_x_lp, lg_node_y_lp, data_width_lp, load_id_width_lp);
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
                                                       ,.load_id_width_p(load_id_width_p)
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
                                                      ,.load_id_width_p(load_id_width_p)
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

  // The manycore has a 2-FF pipelined reset in 16nm, therefore we need
  // to add a 2 cycle latency to all other modules.
  logic reset_r, reset_rr;
  always_ff @(posedge clk)
    begin
      reset_r <= reset;
      reset_rr <= reset_r;
    end

  integer       stderr = 32'h80000002;

   `declare_bsg_manycore_link_sif_s(addr_width_lp, data_width_lp, lg_node_x_lp, lg_node_y_lp, load_id_width_lp);

   bsg_manycore_link_sif_s [S:N][num_tiles_x_lp-1:0]   ver_link_li, ver_link_lo;
   bsg_manycore_link_sif_s [E:W][num_routers_y_lp-1:0] hor_link_li, hor_link_lo;
   bsg_manycore_link_sif_s      [num_tiles_x_lp-1:0]   io_link_li,  io_link_lo;


`ifndef BSG_HETERO_TYPE_VEC
`define BSG_HETERO_TYPE_VEC 0
`endif

  bsg_manycore #
    (
      .dmem_size_p       (dmem_size_lp         )
     ,.icache_entries_p  (icache_entries_num_lp)
     ,.icache_tag_width_p(icache_tag_width_lp)
     ,.data_width_p (data_width_lp)
     ,.addr_width_p (addr_width_lp)
     ,.load_id_width_p (load_id_width_lp)
     ,.epa_addr_width_p (epa_addr_width_lp)
     ,.dram_ch_addr_width_p( dram_ch_addr_width_lp )
     ,.dram_ch_start_col_p ( 1'b0                  )
     ,.num_tiles_x_p(num_tiles_x_lp)
     ,.num_tiles_y_p(num_tiles_y_lp)
     ,.hetero_type_vec_p(`BSG_HETERO_TYPE_VEC)
     // currently west side is stubbed except for upper left tile
     //,.stub_w_p     ({{(num_tiles_y_lp-1){1'b1}}, 1'b0})
     //,.stub_e_p     ({num_tiles_y_lp{1'b1}})
     //,.stub_n_p     ({num_tiles_x_lp{1'b1}})
     //
     // try unstubbing all
     ,.stub_w_p     ({num_tiles_y_lp{1'b0}})
     ,.stub_e_p     ({num_tiles_y_lp{1'b0}})
     ,.stub_n_p     ({num_tiles_x_lp{1'b0}})


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

        ,.io_link_sif_i(io_link_li)
        ,.io_link_sif_o(io_link_lo)

        );

/////////////////////////////////////////////////////////////////////////////////
// Tie the unused I/O
   genvar                   i,j;
   for (i = 0; i < num_routers_y_lp; i=i+1)
     begin: rof2

        bsg_manycore_link_sif_tieoff #(.addr_width_p     (addr_width_lp  )
                                       ,.data_width_p    (data_width_lp  )
                                       ,.load_id_width_p (load_id_width_lp)
                                       ,.x_cord_width_p  (lg_node_x_lp)
                                       ,.y_cord_width_p  (lg_node_y_lp)
                                       ) bmlst
        (.clk_i(clk)
         ,.reset_i(reset_rr)
         ,.link_sif_i(hor_link_lo[W][i])
         ,.link_sif_o(hor_link_li[W][i])
         );

        bsg_manycore_link_sif_tieoff #(.addr_width_p     (addr_width_lp  )
                                       ,.data_width_p    (data_width_lp  )
                                       ,.load_id_width_p (load_id_width_lp)
                                       ,.x_cord_width_p  (lg_node_x_lp   )
                                       ,.y_cord_width_p  (lg_node_y_lp   )
                                       ) bmlst2
        (.clk_i(clk)
         ,.reset_i(reset_rr)
         ,.link_sif_i(hor_link_lo[E][i])
         ,.link_sif_o(hor_link_li[E][i])
         );
     end


   for (i = 0; i < num_tiles_x_lp; i=i+1)
     begin: rof
        // tie off north side; which is inaccessible
        bsg_manycore_link_sif_tieoff #(.addr_width_p     (addr_width_lp)
                                       ,.data_width_p    (data_width_lp)
                                       ,.load_id_width_p (load_id_width_lp)
                                       ,.x_cord_width_p  (lg_node_x_lp)
                                       ,.y_cord_width_p  (lg_node_y_lp)
                                       ) bmlst3
        (.clk_i(clk)
         ,.reset_i(reset_rr)
         ,.link_sif_i(ver_link_lo[N][i])
         ,.link_sif_o(ver_link_li[N][i])
         );
     end

/////////////////////////////////////////////////////////////////////////////////
// instantiate the loader and moniter

   bsg_nonsynth_manycore_io_complex
     #( .icache_entries_num_p(icache_entries_num_lp)
        ,.addr_width_p(addr_width_lp)
        ,.load_id_width_p(load_id_width_lp)
        ,.epa_addr_width_p(epa_addr_width_lp)
        ,.dram_ch_addr_width_p( dram_ch_addr_width_lp)
        ,.data_width_p(data_width_lp)
	,.max_cycles_p(max_cycles_lp)
        ,.num_tiles_x_p(num_tiles_x_lp)
        ,.num_tiles_y_p(num_tiles_y_lp)
	,.tile_id_ptr_p(tile_id_ptr_lp)
        ) io
   (.clk_i(clk)
    ,.reset_i(reset_rr)
    ,.ver_link_sif_i(ver_link_lo[S])
    ,.ver_link_sif_o(ver_link_li[S])
    ,.io_link_sif_i(io_link_lo)
    ,.io_link_sif_o(io_link_li)
    ,.finish_lo(finish_lo)
    ,.success_lo()
    ,.timeout_lo()
    );


/////////////////////////////////////////////////////////////////////////////////
// instantiate the  profiler
`define  PERF_COUNT
`define  TOPLEVEL UUT

`ifdef PERF_COUNT
genvar x,y;
  for (x = 0; x < num_tiles_x_lp; x++) begin: prof_x
    for (y = 0; y < num_tiles_y_lp; y++) begin: prof_y

          //generate the unfreeze signal
          wire  freeze_sig =  `TOPLEVEL.y[y].x[x].tile.proc.h.z.freeze_o;
          logic freeze_r;
          always @(negedge clk) freeze_r  <=  freeze_sig;
          assign          unfreeze_action  =  freeze_r & (~freeze_sig );

          //assign the inputs to the profiler
          manycore_profiler_s trigger_s;
          assign trigger_s.reset_prof   = unfreeze_action   ;
          assign trigger_s.finish_prof  = finish_lo         ;

          assign trigger_s.dmem_stall   = `TOPLEVEL.y[y].x[x].tile.proc.h.z.vanilla_core.stall_mem;
          assign trigger_s.dx_stall     = `TOPLEVEL.y[y].x[x].tile.proc.h.z.vanilla_core.depend_stall;
          assign trigger_s.bt_stall     = `TOPLEVEL.y[y].x[x].tile.proc.h.z.vanilla_core.flush;
          assign trigger_s.in_fifo_full = ~`TOPLEVEL.y[y].x[x].tile.proc.h.z.endp.bme.link_sif_o_cast.fwd.ready_and_rev;
          assign trigger_s.out_fifo_full= ~`TOPLEVEL.y[y].x[x].tile.proc.h.z.endp.bme.link_sif_i_cast.fwd.ready_and_rev;
          assign trigger_s.credit_full  = `TOPLEVEL.y[y].x[x].tile.proc.h.z.endp.out_credits_o == 0 ;
          assign trigger_s.res_acq_stall= `TOPLEVEL.y[y].x[x].tile.proc.h.z.vanilla_core.stall_lrw ;

          //instantiate the profiler
          bsg_manycore_profiler prof_inst(
                .clk_i      ( clk        )
               ,.x_id_i     ( x          )
               ,.y_id_i     ( y          )
               ,.prof_s_i   ( trigger_s  )
          );

    end
  end
`endif

endmodule
