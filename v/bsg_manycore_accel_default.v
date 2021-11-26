
`include "bsg_defines.v"

module bsg_manycore_accel_default 
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
   #(`BSG_INV_PARAM(x_cord_width_p   )
     , `BSG_INV_PARAM(y_cord_width_p )
     , `BSG_INV_PARAM(pod_x_cord_width_p )
     , `BSG_INV_PARAM(pod_y_cord_width_p )
     , `BSG_INV_PARAM(data_width_p   )
     , `BSG_INV_PARAM(addr_width_p   )

     , `BSG_INV_PARAM(icache_entries_p )
     , `BSG_INV_PARAM(icache_tag_width_p )

     , `BSG_INV_PARAM(dmem_size_p ) 
     , `BSG_INV_PARAM(num_vcache_rows_p )
     , `BSG_INV_PARAM(vcache_size_p )
     , `BSG_INV_PARAM(vcache_block_size_in_words_p )
     , `BSG_INV_PARAM(vcache_sets_p )

     , `BSG_INV_PARAM(num_tiles_x_p )
     , `BSG_INV_PARAM(num_tiles_y_p )

     , localparam x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
     , y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)

     , `BSG_INV_PARAM(rev_fifo_els_p) // for FIFO credit counting.
     , `BSG_INV_PARAM(fwd_fifo_els_p) // for FIFO credit counting.

     , localparam credit_counter_width_lp = `BSG_WIDTH(32)
     , parameter proc_fifo_els_p = 4
     , debug_p = 1

     , localparam icache_addr_width_lp = `BSG_SAFE_CLOG2(icache_entries_p)
     , dmem_addr_width_lp = `BSG_SAFE_CLOG2(dmem_size_p)
     , pc_width_lp=(icache_addr_width_lp+icache_tag_width_p)
     , data_mask_width_lp=(data_width_p>>3)
     , reg_addr_width_lp=RV32_reg_addr_width_gp

     , link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

     )
   (input   clk_i
    , input reset_i

    // input and output links
    , input  [link_sif_width_lp-1:0] link_sif_i
    , output [link_sif_width_lp-1:0] link_sif_o

    // subcord within a pod
    , input [x_subcord_width_lp-1:0] my_x_i
    , input [y_subcord_width_lp-1:0] my_y_i

    // pod coordinate
    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i
    );

   initial
     $fatal(1, "This module has not been recently tested, only updated syntactically. Caveat Emptor");
   
   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);

   bsg_manycore_packet_s                   out_packet_li;
   logic                                   out_v_li;
   logic                                   out_ready_lo;
   logic [credit_counter_width_lp-1:0]     out_credits_lo;

   logic [data_width_p-1:0]                in_data_lo;
   logic [(data_width_p>>3)-1:0]           in_mask_lo;
   logic [addr_width_p-1:0]                in_addr_lo;
   logic                                   in_v_lo, in_yumi_li;

   bsg_manycore_endpoint_standard 
     #(.x_cord_width_p (x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.data_width_p(data_width_p)
       ,.addr_width_p(addr_width_p)

       ,.fifo_els_p(proc_fifo_els_p)

       ,.credit_counter_width_p(credit_counter_width_p)
       ,.rev_fifo_els_p(rev_fifo_els_p)

       ,.use_credits_for_local_fifo_p(1)
       ) endp
     (.clk_i
      ,.reset_i

      ,.link_sif_i
      ,.link_sif_o

      ,.in_v_o(in_v_lo)
      ,.in_we_o()
      ,.in_addr_o(in_addr_lo)
      ,.in_data_o(in_data_lo)
      ,.in_mask_o(in_mask_lo)
      ,.in_yumi_i(in_yumi_li)
      ,.in_load_info_o()
      ,.in_src_x_cord_o()
      ,.in_src_y_cord_o()

      ,.returning_v_i('0)
      ,.returning_data_i('0)

      // we feed the endpoint with the data we want to send out
      // it will get inserted into the above link_sif

      ,.out_packet_i (out_packet_li )
      ,.out_v_i    (out_v_li    )
      ,.out_credit_or_ready_o(out_ready_lo)

      ,.returned_v_r_o()
      ,.returned_data_r_o()
      ,.returned_reg_id_r_o()
      ,.returned_pkt_type_r_o()
      ,.returned_fifo_full_o()
      ,.returned_yumi_i('0)

      ,.returned_credit_v_r_o()
      ,.returned_credit_reg_id_r_o()

      ,.out_credits_used_o(out_credits_lo)

      ,.global_x_i({pod_x_i, my_x_i})
      ,.global_y_i({pod_y_i, my_y_i})
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

`BSG_ABSTRACT_MODULE(bsg_manycore_accel_default)
