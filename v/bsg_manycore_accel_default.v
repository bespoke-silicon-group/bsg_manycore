module bsg_manycore_accel_default 
  import bsg_manycore_pkg::*;
   #(parameter x_cord_width_p   = "inv"
     , parameter y_cord_width_p = "inv"
     , parameter data_width_p   = 32
     , parameter addr_width_p   = "inv"

     , parameter icache_entries_p = "inv"
     , parameter icache_tag_width_p = "inv"

     , parameter dmem_size_p = "inv" 
     , parameter vcache_size_p = "inv"
     , parameter vcache_block_size_in_words_p = "inv"
     , parameter vcache_sets_p = "inv"

     , parameter num_tiles_x_p = "inv"

     // number of  packets we can have outstanding
     , parameter max_out_credits_p = 4

     // this is the size of the receive FIFO
     // generally should be the same as max_out_credits_p
     // for whoever is sending us data
     , parameter ep_fifo_els_p = 4

     , parameter freeze_init_p  = 1'b1
     // this credit counter is more for implementing memory fences
     // than containing the number of outstanding remote stores
     // but we use it for the later for now

     , parameter link_sif_width_lp =
       `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

     , parameter branch_trace_en_p = 0

     , parameter debug_p        = 0
     )
   (input   clk_i
    , input reset_i

    // input and output links
    , input  [link_sif_width_lp-1:0] link_sif_i
    , output [link_sif_width_lp-1:0] link_sif_o

    // tile coordinates
    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i

    , output logic freeze_o
    );

   initial
     $fatal(1, "This module has not been recently tested, only updated syntactically. Caveat Emptor");
   

   wire freeze_r;
   assign freeze_o = freeze_r;

   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);

   bsg_manycore_packet_s                   out_packet_li;
   logic                                   out_v_li;
   logic                                   out_ready_lo;
   logic [$clog2(max_out_credits_p+1)-1:0] out_credits_lo;

   logic [data_width_p-1:0]                in_data_lo;
   logic [(data_width_p>>3)-1:0]           in_mask_lo;
   logic [addr_width_p-1:0]                in_addr_lo;
   logic                                   in_v_lo, in_yumi_li;

   bsg_manycore_endpoint_standard 
     #(.x_cord_width_p (x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)

       // how big the fifo is this node
       ,.fifo_els_p    (proc_fifo_els_p)
       ,.data_width_p  (data_width_p)
       ,.addr_width_p  (addr_width_p)
       // how big the fifo is at the next node
       ,.max_out_credits_p(max_out_credits_p)
       ) endp
     (.clk_i
      ,.reset_i

      ,.link_sif_i
      ,.link_sif_o

      ,.in_v_o   (in_v_lo)
      ,.in_yumi_i(in_yumi_li)
      ,.in_data_o(in_data_lo)
      ,.in_mask_o(in_mask_lo)
      ,.in_addr_o(in_addr_lo)

      // we feed the endpoint with the data we want to send out
      // it will get inserted into the above link_sif

      ,.out_packet_i (out_packet_li )
      ,.out_v_i    (out_v_li    )
      ,.out_ready_o(out_ready_lo)

      ,.out_credits_o(out_credits_lo)

      ,.my_x_i
      ,.my_y_i
      );

   // ADDRESS DECODER
   //
   //

   // create a decoder that allows us to turn an address into enable
   // signals for the endpoints

   localparam num_endpoints_lp=3;

   localparam lg_num_endpoints_lp = `BSG_SAFE_CLOG2(num_endpoints_lp);
   wire [num_endpoints_lp-1:0] endpoint_en_vec_lo, endpoint_yumi_vec;

   bsg_decode_with_v #(.num_out_p(num_endpoints_lp)) decoder
   (
    .v_i (in_v_lo                           )
    ,.i(in_addr_lo[0+:lg_num_endpoints_lp])
    ,.o(endpoint_en_vec_lo                   )
    );

   // we eat the data if any of the endpoints want it
   assign in_yumi_li = | endpoint_yumi_vec;

   // ADDRESS 0
   //
   // set the address tag for outgoing packets
   //

   logic [addr_width_p-1:0]    out_pkt_addr_n, out_pkt_addr_r;
   assign out_pkt_addr_n = in_data_lo[0+:addr_width_p];

   bsg_dff_reset_en #(.width_p(addr_width_p)) out_pkt_addr_reg
     (
      .data_i  (out_pkt_addr_n    )
      ,.en_i   (endpoint_en_vec_lo[0])  // located at address 0
      ,.reset_i(reset_i           )
      ,.clk_i(clk_i             )
      ,.data_o (out_pkt_addr_r    )
      );

   assign endpoint_yumi_vec[0] = endpoint_en_vec_lo[0];

   // ADDRESS 1
   //
   // set the Y X coordinate for outgoing packets
   //

   localparam yx_width_lp = y_cord_width_p + x_cord_width_p;

   logic [yx_width_lp-1:0]     out_pkt_dest_r;

   bsg_dff_reset_en #(.width_p(yx_width_lp)) out_pkt_dest_reg
     (.data_i   (in_data_lo[0+:yx_width_lp])
      ,.en_i    (endpoint_en_vec_lo[1])
      ,.reset_i
      ,.clk_i(clk_i)
      ,.data_o (out_pkt_dest_r)
      );

   assign endpoint_yumi_vec[1] = endpoint_en_vec_lo[1];

   // OUTGOING PACKET ASSEMBLY
   //
   // build the outgoing packet based on the configuration state
   // and standard values
   //

   always_comb
     begin
        out_packet_li.addr                            = out_pkt_addr_r;
        { out_packet_li.y_cord, out_packet_li.x_cord} = out_pkt_dest_r;

        // standard values
        out_packet_li.return_pkt.y_cord = my_y_i;
        out_packet_li.return_pkt.x_cord = my_x_i;
        out_packet_li.op_ex             = 4'b1111;  // write all bytes
        out_packet_li.op                = 2'b1;     // write operation
     end

   // DEBUG
   //
   // build the outgoing packet based on the configuration state
   // and standard values
   //

   localparam accel_debug_p=1;

   /* synopsys translate_off*/
   if (accel_debug_p)
   always @(negedge clk_i)
     begin
        if (in_v_lo | out_v_li | in_yumi_li)
        $display("## bsg_manycore_accel_default (y,x=%d,%d) (in: v=%b, d_i=%b, a_i=0h%h, yumi=%b, endpoint=%b) (out:v=%b,d_o=%b,ready=%b)"
                 , my_y_i, my_x_i, in_v_lo, in_data_lo, in_addr_lo, in_yumi_li, endpoint_en_vec_lo
                 , out_v_li, out_packet_li, out_ready_lo
                 );
     end
   /* synopsys translate_on */

   // ****************************************************************
   // * CUSTOMIZE BELOW (and above, if you need to)
   // *
   // *
   // *
   //
   // ADDRESS 2 (CUSTOMIZE THIS AND OTHER ADDRESSES)
   //
   // currently, we just forward packets along, but only if we have credits
   //

   assign out_v_li   = endpoint_en_vec_lo[2] & (|out_credits_lo);

   // we deque the incoming packet to address 2 only if we can send out
   // otherwise we would lose data

   assign endpoint_yumi_vec[2] = out_v_li & out_ready_lo;

   always_comb
     begin
        out_packet_li.data = in_data_lo;
     end


endmodule
