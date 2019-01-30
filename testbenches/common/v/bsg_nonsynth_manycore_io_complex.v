
`include "bsg_manycore_packet.vh"

// currently only supports south side of chip

module bsg_nonsynth_manycore_io_complex
  #(
     icache_entries_num_p   = -1   // entries of the icache number
    ,max_cycles_p   = -1
    ,addr_width_p   = -1
    ,load_id_width_p = 5
    ,epa_addr_width_p = -1
    ,dram_ch_num_p       = 0
    ,dram_ch_addr_width_p=-1
    ,data_width_p  = 32
    ,num_tiles_x_p = -1
    ,num_tiles_y_p = -1
    ,load_rows_p    =  num_tiles_y_p
    ,load_cols_p    =  num_tiles_x_p
    ,tile_id_ptr_p = -1
    ,src_x_cord_p = num_tiles_x_p -1 
    ,x_cord_width_lp  = `BSG_SAFE_CLOG2(num_tiles_x_p)
    ,y_cord_width_lp  = `BSG_SAFE_CLOG2(num_tiles_y_p + 2)
    ,include_dram_model = 1'b1

    //parameters for victim cache    
    ,init_vcache_p   = 0
    ,vcache_entries_p = -1 
    ,vcache_ways_p    = -1 

    ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp,load_id_width_p)

    )
   (input clk_i
    ,input reset_i

    ,input  [num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] ver_link_sif_i
    ,output [num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] ver_link_sif_o

    ,input  [num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] io_link_sif_i
    ,output [num_tiles_x_p-1:0][bsg_manycore_link_sif_width_lp-1:0] io_link_sif_o

    ,output finish_lo
	,output success_lo
	,output timeout_lo
    );

   initial
     begin
        $display("## creating manycore complex num_tiles (x,y) = %-d,%-d (%m)", num_tiles_x_p, num_tiles_y_p);
     end

   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp,load_id_width_p);

   localparam packet_width_lp = `bsg_manycore_packet_width(addr_width_p, data_width_p, x_cord_width_lp, y_cord_width_lp, load_id_width_p);

   // we add this for easier debugging
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp,load_id_width_p);
   bsg_manycore_link_sif_s  [num_tiles_x_p-1:0] io_link_sif_i_cast, io_link_sif_o_cast;
   assign io_link_sif_i_cast = io_link_sif_i;
   assign io_link_sif_o      = io_link_sif_o_cast;

   wire [39:0] cycle_count;

   bsg_cycle_counter #(.width_p(40),.init_val_p(0))
   cc (.clk_i(clk_i), .reset_i(reset_i), .ctr_r_o(cycle_count));


   bsg_manycore_packet_s  loader_data_lo;
   logic                      loader_v_lo;
   logic                      loader_ready_li;

   logic reset_r;
   always_ff @(posedge clk_i)
     begin
       reset_r <= reset_i;
     end

   bsg_manycore_spmd_loader
     #( .icache_entries_num_p    ( icache_entries_num_p)
        ,.num_rows_p    (num_tiles_y_p)
        ,.num_cols_p    (num_tiles_x_p)
        ,.load_rows_p   (load_rows_p)
        ,.load_cols_p   (load_cols_p)
        ,.data_width_p  (data_width_p)
        ,.addr_width_p  (addr_width_p)
        ,.load_id_width_p (load_id_width_p)
        ,.epa_addr_width_p (epa_addr_width_p)
        ,.dram_ch_num_p       ( dram_ch_num_p       )
        ,.dram_ch_addr_width_p( dram_ch_addr_width_p )
        ,.tile_id_ptr_p (tile_id_ptr_p)
        ,.init_vcache_p (init_vcache_p)
        ,.vcache_entries_p ( vcache_entries_p )
        ,.vcache_ways_p    ( vcache_ways_p    )
        ) spmd_loader
       ( .clk_i     (clk_i)
         ,.reset_i  (reset_r)
         ,.data_o   (loader_data_lo )
         ,.v_o      (loader_v_lo    )
         ,.ready_i  (loader_ready_li)
         ,.my_x_i   ( x_cord_width_lp ' (src_x_cord_p) )
         ,.my_y_i   ( y_cord_width_lp ' (num_tiles_y_p) )
         );
/*
   bsg_manycore_io_complex_rom
   #( .addr_width_p(addr_width_p)
      ,.width_p     (data_width_p)
      ) spmd_rom
     ( .addr_i (mem_addr)
       ,.data_o (mem_data)
       );

*/
   wire [num_tiles_x_p-1:0] finish_lo_vec;
   assign finish_lo = | finish_lo_vec;
   
   wire [num_tiles_x_p-1:0] success_lo_vec;
   assign success_lo = | success_lo_vec;
   
   wire [num_tiles_x_p-1:0] timeout_lo_vec;
   assign timeout_lo = | timeout_lo_vec;

   genvar                   i;
   //-----------------------------------------------------------------
   // Connects dram model
   if(include_dram_model) begin
        for (i = 0; i < num_tiles_x_p; i=i+1) begin
             
         bsg_manycore_ram_model#( .x_cord_width_p    (x_cord_width_lp)
                                 ,.y_cord_width_p    (y_cord_width_lp)
                                 ,.data_width_p      (data_width_p   )

                                 ,.addr_width_p      (addr_width_p   )
                                 ,.load_id_width_p   (load_id_width_p)
                                 ,.els_p             (2**dram_ch_addr_width_p)
                                )ram
        (  .clk_i
         , .reset_i

         // mesh network
         , .link_sif_i (ver_link_sif_i[i] )
         , .link_sif_o (ver_link_sif_o[i] )

         , .my_x_i ( x_cord_width_lp'(i)               )
         , .my_y_i ( y_cord_width_lp'(num_tiles_y_p+1) )

         );
        end
   end
   // we only set such a high number because we
   // know these packets can always be consumed
   // at the recipient and do not require any
   // forwarded traffic. for an accelerator
   // this would not be the case, and this
   // number must be set to the same as the
   // number of elements in the accelerator's
   // input fifo

   localparam spmd_max_out_credits_lp = 128;
   for (i = 0; i < num_tiles_x_p; i=i+1)
     begin: rof

        wire pass_thru_ready_lo;

        localparam credits_lp = (i== src_x_cord_p) ? spmd_max_out_credits_lp : 4;

        wire [`BSG_SAFE_CLOG2(credits_lp+1)-1:0] creds;

        logic [x_cord_width_lp-1:0] pass_thru_x_li;
        logic [y_cord_width_lp-1:0] pass_thru_y_li;

        assign pass_thru_x_li = x_cord_width_lp ' (i);
        assign pass_thru_y_li = y_cord_width_lp ' (num_tiles_y_p);

        // hook up the ready signal if this is the SPMD loader
        // we handle credits here but could do it in the SPMD module too

        if (i== src_x_cord_p)
          begin: fi
             assign loader_ready_li = pass_thru_ready_lo & (|creds);

	     if (0)
             always @(negedge clk_i)
               begin
                  if (~reset_i & loader_ready_li & loader_v_lo)
                    begin
                       $write("Loader: Transmitted addr=%-d'h%h (x_cord_width_lp=%-d)(y_cord_width_lp=%-d) "
                              ,addr_width_p, mem_addr, x_cord_width_lp, y_cord_width_lp);
                       `write_bsg_manycore_packet_s(loader_data_lo);
                       $write("\n");
                    end
                end

          end

        bsg_nonsynth_manycore_monitor #(.x_cord_width_p   (x_cord_width_lp)
                                        ,.y_cord_width_p  (y_cord_width_lp)
                                        ,.addr_width_p    (addr_width_p)
                                        ,.data_width_p    (data_width_p)
                                        ,.load_id_width_p (load_id_width_p)
                                        ,.channel_num_p   (i)
                                        ,.max_cycles_p    (max_cycles_p)
                                        ,.pass_thru_p     (i== src_x_cord_p)
                                        // for the SPMD loader we don't anticipate
                                        // any backwards flow control; but for an
                                        // accelerator, we must be much more careful about
                                        // setting this
                                        ,.pass_thru_max_out_credits_p (credits_lp)
                                        ) bmm (.clk_i             (clk_i)
                                               ,.reset_i          (reset_r)
                                               ,.link_sif_i       (io_link_sif_i_cast[i])
                                               ,.link_sif_o       (io_link_sif_o_cast[i])
                                               ,.pass_thru_data_i (loader_data_lo )
                                               ,.pass_thru_v_i    (loader_v_lo & loader_ready_li    )
                                               ,.pass_thru_ready_o(pass_thru_ready_lo)
                                               ,.pass_thru_out_credits_o(creds)
                                               ,.pass_thru_x_i(pass_thru_x_li)
                                               ,.pass_thru_y_i(pass_thru_y_li)
                                               ,.cycle_count_i(cycle_count)
                                               ,.finish_o     (finish_lo_vec[i])
											   ,.success_o(success_lo_vec[i])
											   ,.timeout_o(timeout_lo_vec[i])
                                               );
     end

endmodule
