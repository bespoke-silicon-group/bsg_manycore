// Endpoint standard provides the simplified interface for some nodes that connect to the network.
//
// Originally designed by Michael B. Taylor <prof.taylor@gmail.com>
// Extended by Shaolin <shawnless.xie@gmail.com> and Bandhav <bandhav@uw.edu>
// Refactored by Tommy.
//
// See following google doc for more information.
//
// https://docs.google.com/document/d/1-i62N72pfx2Cd_xKT3hiTuSilQnuC0ZOaSQMG8UPkto/edit?usp=sharing
//
//   node                               endpoint_standard             router
//
// -------------|     1. in_request     |-------------- |          |---------|
//              |  <------------------- |               |          |         |
//      Client  |                       |               | link_in  |         |
//              |     2. out_response   |               |<---------|         |
//              |  -------------------> |               |          |         |
//              |                       |               |          |         |
//              |     3. out_request    |               |          |         |
//      Master  |  -------------------> |               |          |         |
//              |                       |               | link_out |         |
//              |     4. in_response    |               |--------->|         |
//              |  <------------------- |               |          |         |
//--------------                        |---------------|          |---------|

module bsg_manycore_endpoint_standard 
  import bsg_manycore_pkg::*; 
  #(parameter x_cord_width_p          = "inv"
    , parameter y_cord_width_p         = "inv"
    , parameter fifo_els_p             = "inv"
    , parameter data_width_p           = 32
    , parameter addr_width_p           = "inv"

    // if you are doing a streaming application then
    // you might want to turn this off because it is fairly normal
    , parameter max_out_credits_p      = "inv"
    , parameter warn_out_of_credits_p  = 1
    , parameter debug_p                = 0

    , parameter use_credits_for_local_fifo_p = 0

    , parameter packet_width_lp =
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    , parameter return_packet_width_lp =
      `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
    , parameter bsg_manycore_link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i

    // connect to mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    //--------------------------------------------------------
    // 1. in_request signal group
    , output                            in_v_o
    , output [data_width_p-1:0]         in_data_o
    , output [(data_width_p>>3)-1:0]    in_mask_o
    , output [addr_width_p-1:0]         in_addr_o
    , output                            in_we_o
    , output bsg_manycore_load_info_s   in_load_info_o
    , output [x_cord_width_p-1:0]       in_src_x_cord_o
    , output [y_cord_width_p-1:0]       in_src_y_cord_o
    , input                             in_yumi_i

    //--------------------------------------------------------
    // 2. out_response signal group
    //    responses that will send back to the network
    , input [data_width_p-1:0]              returning_data_i
    , input                                 returning_v_i

    //--------------------------------------------------------
    // 3. out_request signal group
    //    request that will send to the network
    , input                                  out_v_i
    , input  [packet_width_lp-1:0]           out_packet_i
    , output                                 out_credit_or_ready_o

    //--------------------------------------------------------
    // 4. in_response signal group
    //    responses that send back from the network
    //    the node shold always be ready to receive this response.
    , output [data_width_p-1:0]                 returned_data_r_o
    , output [bsg_manycore_reg_id_width_gp-1:0]  returned_reg_id_r_o
    , output                                    returned_v_r_o
    , output bsg_manycore_return_packet_type_e  returned_pkt_type_r_o
    , input                                     returned_yumi_i
    , output                                    returned_fifo_full_o


    , output                                   returned_credit_v_r_o
    , output [bsg_manycore_reg_id_width_gp-1:0]  returned_credit_reg_id_r_o

    , output [$clog2(max_out_credits_p+1)-1:0] out_credits_o

    // tile coordinates (coordinate in a global array)
    // currently, for debugging only
    , input   [x_cord_width_p-1:0] global_x_i
    , input   [y_cord_width_p-1:0] global_y_i

  );

  // Instantiate the endpoint.
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_packet_s packet_lo;
  logic packet_v_lo;
  logic packet_yumi_li;

  bsg_manycore_return_packet_s returning_packet_li;
  logic returning_v_li;
  logic returning_ready_lo;

  bsg_manycore_return_packet_s returned_packet_lo;
  logic returned_packet_v_lo;
  logic returned_yumi_li;

  bsg_manycore_endpoint #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.fifo_els_p(fifo_els_p)
  ) bme (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    ,.packet_o(packet_lo)
    ,.packet_v_o(packet_v_lo)
    ,.packet_yumi_i(packet_yumi_li)

    ,.packet_i(out_packet_i)
    ,.packet_v_i(out_v_i)
    ,.packet_credit_or_ready_o(out_credit_or_ready_o)

    ,.return_packet_o(returned_packet_lo)
    ,.return_packet_v_o(returned_packet_v_lo)
    ,.return_packet_fifo_full_o(returned_fifo_full_o)
    ,.return_packet_yumi_i(returned_yumi_li)

    ,.return_packet_i(returning_packet_li)
    ,.return_packet_v_i(returning_v_li)
    ,.return_packet_ready_o(returning_ready_lo)
  );


  // ----------------------------------------------------------------------------------------
  // Handle incoming request packets
  // ----------------------------------------------------------------------------------------
  // signals between FIFO to lock_ctrl
  wire in_yumi_lo, in_v_li;

  wire [data_width_p-1:0] in_data_lo = packet_lo.payload;
  wire [addr_width_p-1:0] in_addr_lo = packet_lo.addr;
  wire[(data_width_p>>3)-1:0] in_mask_lo = (packet_lo.op_v2 == e_remote_sw)
    ? 4'b1111
    : packet_lo.reg_id.store_mask_s.mask;

  wire pkt_remote_store   = packet_v_lo & ((packet_lo.op_v2 == e_remote_store  ) | (packet_lo.op_v2 == e_remote_sw));
  wire pkt_remote_load    = packet_v_lo & (packet_lo.op_v2 == e_remote_load   );
  wire pkt_remote_amo     = packet_v_lo & (packet_lo.op_v2 == e_remote_amoswap );

  bsg_manycore_load_info_s pkt_load_info;
  assign pkt_load_info = packet_lo.payload.load_info_s.load_info;
  assign in_load_info_o = pkt_load_info;
   
  // dequeue only if
  // 1. The outside is ready (they want to yumi the singal),
  // 2. The returning path is ready
  wire rc_fifo_ready_lo, rc_fifo_v_lo, rc_fifo_yumi_li;

  assign packet_yumi_li = in_yumi_lo  & (returning_ready_lo & rc_fifo_ready_lo );
  assign in_v_li        = packet_v_lo & (returning_ready_lo & rc_fifo_ready_lo );

  wire [data_width_p-1:0] comb_returning_data_lo;
  wire comb_returning_v_lo;

  bsg_manycore_lock_ctrl #(
    .data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.max_out_credits_p(max_out_credits_p)
    ,.debug_p(1'b0)
  ) lock_ctrl (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
     // local endpoint incoming data interface
    ,.in_v_i       (in_v_li         )
    ,.in_yumi_o    (in_yumi_lo      )
    ,.in_data_i    (in_data_lo      )
    ,.in_mask_i    (in_mask_lo      )
    ,.in_addr_i    (in_addr_lo      )
    ,.in_we_i      (pkt_remote_store)
    ,.in_amo_op_i  (pkt_remote_amo  )
    ,.in_x_cord_i  (packet_lo.src_x_cord )
    ,.in_y_cord_i  (packet_lo.src_y_cord )
    // combined  incoming data interface
    ,.comb_v_o      (in_v_o         )
    ,.comb_yumi_i   (in_yumi_i      )
    ,.comb_data_o   (in_data_o      )
    ,.comb_mask_o   (in_mask_o      )
    ,.comb_addr_o   (in_addr_o      )
    ,.comb_we_o     (in_we_o        )
    ,.comb_x_cord_o (in_src_x_cord_o)
    ,.comb_y_cord_o (in_src_y_cord_o)

    // The memory read value
    ,.returning_data_i(returning_data_i)
    ,.returning_v_i(returning_v_i)
    // The output read value
    ,.comb_returning_data_o(comb_returning_data_lo)
    ,.comb_returning_v_o(comb_returning_v_lo)
  );


  // we hide the request if the returning path is not ready

  // ----------------------------------------------------------------------------------------
  // Handle outgoing credit packet
  // ----------------------------------------------------------------------------------------
   typedef struct packed {
      bsg_manycore_return_packet_type_e pkt_type;
      logic [(y_cord_width_p)-1:0] y_cord;
      logic [(x_cord_width_p)-1:0] x_cord;
      logic [bsg_manycore_reg_id_width_gp-1:0] reg_id;
   } returning_credit_info;

   returning_credit_info  rc_fifo_li, rc_fifo_lo;

  // AND-OR 5 LSBs of each byte of payload to get the payload hash and return it as reg_id for e_remote_store.
  wire [bsg_manycore_reg_id_width_gp-1:0] payload_reg_id;
  bsg_manycore_reg_id_decode pd0 (
    .data_i(packet_lo.payload)
    ,.mask_i(packet_lo.reg_id.store_mask_s.mask)
    ,.reg_id_o(payload_reg_id)
  );
    


  always_comb begin
    rc_fifo_li.y_cord = packet_lo.src_y_cord;
    rc_fifo_li.x_cord = packet_lo.src_x_cord;

    case (packet_lo.op_v2)
      e_remote_store: begin
        rc_fifo_li.pkt_type = e_return_credit;
        rc_fifo_li.reg_id = payload_reg_id;
      end

      e_remote_sw: begin
        rc_fifo_li.pkt_type = e_return_credit;
        rc_fifo_li.reg_id = packet_lo.reg_id;
      end
    
      e_remote_load: begin
        rc_fifo_li.pkt_type = pkt_load_info.float_wb
          ? e_return_float_wb
          : e_return_int_wb;
        rc_fifo_li.reg_id = packet_lo.reg_id;
      end

      e_remote_amoswap: begin
        rc_fifo_li.pkt_type = e_return_int_wb;
        rc_fifo_li.reg_id = packet_lo.reg_id;
      end
      
      // should not happen.
      default: begin
        rc_fifo_li.pkt_type = e_return_int_wb;
        rc_fifo_li.reg_id = packet_lo.reg_id;
      end
    endcase
  end


  bsg_two_fifo #(
    .width_p($bits(returning_credit_info))
  ) return_credit_fifo (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    // input side
    ,.ready_o (rc_fifo_ready_lo)// early
    ,.data_i  (rc_fifo_li      )// late
    ,.v_i     (packet_yumi_li)// late

    // output side
    ,.v_o     (rc_fifo_v_lo    )// early
    ,.data_o  (rc_fifo_lo      )// early
    ,.yumi_i  (rc_fifo_yumi_li )// late
  );

  // there is 1 cycle delay between the "RC_FIFO is not full" and "returning data
  // valid". Even in current cycle the "RC_FIFO is not full" and we yumi
  // a incoming request. In next cycle the "RC_FIFO maybe full" and we can
  // not receive the returning data.
  // THUS WE NEED A HOLD MODULE TO HOLD THE RETURNING DATA
  wire [data_width_p-1:0] holded_returning_data_lo;
  wire holded_returning_v_lo;

  bsg_1hold #(
    .data_width_p(data_width_p)
  ) returning_hold (
    .clk_i(clk_i)
    ,.v_i(comb_returning_v_lo)
    ,.data_i(comb_returning_data_lo)

    ,.v_o(holded_returning_v_lo)
    ,.data_o(holded_returning_data_lo)
    ,.hold_i(~returning_ready_lo & holded_returning_v_lo )
  );

  wire load_store_ready = holded_returning_v_lo;

  assign rc_fifo_yumi_li =  rc_fifo_v_lo & returning_ready_lo & load_store_ready;

  assign returning_v_li =  rc_fifo_v_lo & load_store_ready;

  assign returning_packet_li = '{
    pkt_type : rc_fifo_lo.pkt_type
    , data   : holded_returning_data_lo
    , y_cord : rc_fifo_lo.y_cord
    , x_cord : rc_fifo_lo.x_cord
    , reg_id : rc_fifo_lo.reg_id
  };

  // ----------------------------------------------------------------------------------------
  // Handle returned credit & data
  // ----------------------------------------------------------------------------------------
  wire launching_out;
  if (use_credits_for_local_fifo_p) begin
    assign launching_out = out_v_i;
  end
  else begin
    assign launching_out = out_v_i & out_credit_or_ready_o;
  end
  wire returned_credit = returned_packet_v_lo & returned_yumi_li;

  bsg_counter_up_down #(
    .max_val_p(max_out_credits_p)
    ,.init_val_p(max_out_credits_p)
    ,.max_step_p(1)
  ) out_credit_ctr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.down_i(launching_out) // launch remote store
    ,.up_i(returned_credit) // receive credit back
    ,.count_o(out_credits_o)
  );

  assign returned_data_r_o     = returned_packet_lo.data;
  assign returned_reg_id_r_o   = returned_packet_lo.reg_id;
  assign returned_pkt_type_r_o = returned_packet_lo.pkt_type;
  assign returned_v_r_o        = returned_packet_v_lo & (returned_packet_lo.pkt_type != e_return_credit);
  assign returned_yumi_li      = returned_yumi_i | (returned_packet_v_lo & (returned_packet_lo.pkt_type == e_return_credit));



  assign returned_credit_v_r_o      = returned_credit;
  assign returned_credit_reg_id_r_o = returned_packet_lo.reg_id;


  //              //
  //  Assertions  //
  //              //

  // synopsys translate_off
  if (debug_p) begin
    always_ff @(negedge clk_i) begin
      if (returned_credit)
        $display("## return packet received by (x,y)=%x,%x",global_x_i,global_y_i);

      if (out_v_i)
        $display("## attempting remote store send of data %x, out_credit_or_ready_o = %x (%m)",out_packet_i,out_credit_or_ready_o);
    end
  end

  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      if (packet_v_lo) begin
        assert(
          (packet_lo.op_v2 != e_remote_amoadd)
          & (packet_lo.op_v2 != e_remote_amoxor)
          & (packet_lo.op_v2 != e_remote_amoand)
          & (packet_lo.op_v2 != e_remote_amoor)
          & (packet_lo.op_v2 != e_remote_amomin)
          & (packet_lo.op_v2 != e_remote_amomax)
          & (packet_lo.op_v2 != e_remote_amominu)
          & (packet_lo.op_v2 != e_remote_amomaxu)
        ) else $error("[BSG_ERROR] Incoming packet has an unsupported amo type. op_v2=%d", packet_lo.op_v2);
      end
    end
  end


  logic out_of_credits_warned = 0;

  if (warn_out_of_credits_p)
   always @ (negedge clk_i)
     begin
        if ( ~(reset_i) & ~out_of_credits_warned)
        assert (out_credits_o === 'X || out_credits_o > 0) else
          begin
             $display("## out of remote store credits(=%d) x,y=%d,%d displaying only once (%m)",out_credits_o,global_x_i,global_y_i);
             $display("##   (this may be a performance problem; or normal behavior)");
             out_of_credits_warned = 1;
          end
     end

   `declare_bsg_manycore_link_sif_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p);
   bsg_manycore_link_sif_s link_sif_i_cast;
   assign link_sif_i_cast = link_sif_i;

   bsg_manycore_return_packet_s return_packet;
   assign return_packet = link_sif_i_cast.rev.data;

   logic reset_r ;
   always_ff @(posedge clk_i)  reset_r <= reset_i;

   always_ff @(negedge clk_i)
     assert ( (reset_r!==0) | ~link_sif_i_cast.rev.v | ({return_packet.y_cord, return_packet.x_cord} == {global_y_i, global_x_i}))
       else begin
         $error("## errant credit packet v=%b for YX=%d,%d landed at YX=%d,%d (%m)"
                ,link_sif_i_cast.rev.v
                ,link_sif_i_cast.rev.data[x_cord_width_p+:y_cord_width_p]
                ,link_sif_i_cast.rev.data[0+:x_cord_width_p]
                ,global_y_i,global_x_i);
        $finish();
       end

   always_ff @(negedge clk_i) begin
        if( (returned_v_r_o === 1'b1) && ( returned_yumi_i != 1'b1) && returned_fifo_full_o ) begin
                $display("## Returned response will be dropped at YX=%d, %d (%m)", global_y_i, global_x_i);
                $finish();
        end
  end
  // synopsys translate_on

endmodule


