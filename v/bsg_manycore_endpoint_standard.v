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

    , parameter credit_counter_width_p = `BSG_WIDTH(32)
    , parameter warn_out_of_credits_p  = 1
    , parameter debug_p                = 0

    // size of outgoing response fifo
    , parameter rev_fifo_els_p         = 3
    , parameter lg_rev_fifo_els_lp     = `BSG_WIDTH(rev_fifo_els_p)

    // fwd fifo interface
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
    , output logic                            in_v_o
    , output logic [data_width_p-1:0]         in_data_o
    , output logic [(data_width_p>>3)-1:0]    in_mask_o
    , output logic [addr_width_p-1:0]         in_addr_o
    , output logic                            in_we_o
    , output bsg_manycore_load_info_s   in_load_info_o
    , output logic [x_cord_width_p-1:0]       in_src_x_cord_o
    , output logic [y_cord_width_p-1:0]       in_src_y_cord_o
    , input                                   in_yumi_i

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

    , output [credit_counter_width_p-1:0] out_credits_o

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

  bsg_manycore_return_packet_s return_packet_li;
  logic return_packet_v_li;
  logic return_packet_credit_or_ready_lo;

  bsg_manycore_return_packet_s return_packet_lo;
  logic return_packet_v_lo;
  logic return_packet_yumi_li;

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

    // RX
    ,.packet_o(packet_lo)
    ,.packet_v_o(packet_v_lo)
    ,.packet_yumi_i(packet_yumi_li)

    ,.return_packet_i(return_packet_li)
    ,.return_packet_v_i(return_packet_v_li)
    ,.return_packet_credit_or_ready_o(return_packet_credit_or_ready_lo)

    // TX
    ,.packet_i(out_packet_i)
    ,.packet_v_i(out_v_i)
    ,.packet_credit_or_ready_o(out_credit_or_ready_o)

    ,.return_packet_o(return_packet_lo)
    ,.return_packet_v_o(return_packet_v_lo)
    ,.return_packet_fifo_full_o(returned_fifo_full_o)
    ,.return_packet_yumi_i(return_packet_yumi_li)

  );



  // ----------------------------------------------------------------------------------------
  // Handle incoming request packets
  // ----------------------------------------------------------------------------------------

  // credit counting on response fifo
  // By default, 3 credits are needed, because the round trip to get the credit back takes three cycles.
  // FWD_FIFO->CORE->REV_FIFO->CREDIT.
  logic [lg_rev_fifo_els_lp-1:0] rev_fifo_credit_r;
  wire [lg_rev_fifo_els_lp-1:0] rev_fifo_credit_available = rev_fifo_credit_r + return_packet_credit_or_ready_lo;
  wire rev_fifo_has_space = (rev_fifo_credit_available != '0);

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      rev_fifo_credit_r <= (lg_rev_fifo_els_lp)'(rev_fifo_els_p);
    end
    else begin
      rev_fifo_credit_r <= rev_fifo_credit_available - (packet_v_lo & packet_yumi_li);
    end
  end


  // 1-bit lock for amoswap
  // any atomic op other than amoswap has no effect.
  logic lock_r, lock_n;
  logic lock_v_r, lock_v_n;
  logic lock_return_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      lock_r <= 1'b0;
      lock_v_r <= 1'b0;
      lock_return_r <= 1'b0;
    end
    else begin
      lock_r <= lock_n;
      lock_v_r <= lock_v_n;
      lock_return_r <= lock_r;
    end
  end


  // AND-OR 5 LSBs of each byte of payload to get the payload hash and return it as reg_id for e_remote_store.
  wire [bsg_manycore_reg_id_width_gp-1:0] payload_reg_id;
  bsg_manycore_reg_id_decode pd0 (
    .data_i(packet_lo.payload)
    ,.mask_i(packet_lo.reg_id.store_mask_s.mask)
    ,.reg_id_o(payload_reg_id)
  );



  // present the incoming packet to the core, if there are credits left and  it is load or store.
  logic [bsg_manycore_reg_id_width_gp-1:0] return_reg_id;
  bsg_manycore_return_packet_type_e return_pkt_type;

  always_comb begin
    in_v_o    = 1'b0;
    in_we_o   = 1'b0;
    in_data_o = packet_lo.payload;
    in_mask_o = 4'b1111;
    in_addr_o = packet_lo.addr;
    in_load_info_o =  packet_lo.payload.load_info_s.load_info;
    in_src_x_cord_o = packet_lo.src_x_cord;
    in_src_y_cord_o = packet_lo.src_y_cord;
    packet_yumi_li = 1'b0;

    lock_n = lock_r;
    lock_v_n = 1'b0;

    return_reg_id = packet_lo.reg_id;
    return_pkt_type = e_return_credit;

    case (packet_lo.op_v2)
      e_remote_load: begin
        in_v_o = packet_v_lo & rev_fifo_has_space;
        packet_yumi_li = in_yumi_i;
        return_pkt_type = packet_lo.payload.load_info_s.load_info.float_wb
          ? e_return_float_wb
          : e_return_int_wb;
      end

      e_remote_sw: begin
        in_v_o = packet_v_lo & rev_fifo_has_space;
        in_we_o = 1'b1;
        in_mask_o = 4'b1111;
        packet_yumi_li = in_yumi_i;
        return_pkt_type = e_return_credit;
      end

      e_remote_store: begin
        in_v_o = packet_v_lo & rev_fifo_has_space;
        in_we_o = 1'b1;
        in_mask_o = packet_lo.reg_id.store_mask_s.mask;
        packet_yumi_li = in_yumi_i;
        return_pkt_type = e_return_credit;
        return_reg_id = payload_reg_id;
      end

      e_remote_amoswap: begin
        packet_yumi_li = packet_v_lo & rev_fifo_has_space;
        lock_v_n = packet_v_lo & rev_fifo_has_space;
        lock_n = (packet_v_lo & rev_fifo_has_space)
          ? packet_lo.payload[0]
          : lock_r;
        return_pkt_type = e_return_int_wb;
      end

      // for other opcodes, print error.
      default: begin
        assert final((reset_i !== 1'b0) | (packet_v_lo !== 1'b1))
          else $error("[BSG_ERROR] Unexpected op_v2 received at bsg_manycore_endpoint_standard: %b", packet_lo.op_v2);
      end
    endcase

  end


  // Save return info.
  typedef struct packed {
    logic [y_cord_width_p-1:0] y_cord;
    logic [x_cord_width_p-1:0] x_cord;
    logic [bsg_manycore_reg_id_width_gp-1:0] reg_id;
    bsg_manycore_return_packet_type_e pkt_type;
  } return_info_s;

  return_info_s return_info_r;

  always_ff @ (posedge clk_i) begin
    if (packet_v_lo & packet_yumi_li) begin
      return_info_r <= '{
        x_cord : packet_lo.src_x_cord,
        y_cord : packet_lo.src_y_cord,
        reg_id : return_reg_id,
        pkt_type : return_pkt_type
      };
    end
  end


  // return logic
  assign return_packet_v_li = lock_v_r | returning_v_i;

  assign return_packet_li = '{
    pkt_type  : return_info_r.pkt_type,
    data      : lock_v_r
                ? (data_width_p)'(lock_return_r)
                : returning_data_i,
    y_cord    : return_info_r.y_cord,
    x_cord    : return_info_r.x_cord,
    reg_id    : return_info_r.reg_id
  };


  // synopsys translate_off
  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      assert(~lock_v_r | ~returning_v_i)
        else $error("[BSG_ERROR] lock_v_r and returning_v_i both 1.");
    end
  end
  // synopsys translate_on





  // ----------------------------------------------------------------------------------------
  // Handle outgoing request packets
  // ----------------------------------------------------------------------------------------


  wire launching_out = out_v_i & ((use_credits_for_local_fifo_p == 1) | out_credit_or_ready_o);
  wire returned_credit = return_packet_v_lo & return_packet_yumi_li;

  bsg_counter_up_down #(
    .max_val_p((1<<credit_counter_width_p)-1)
    ,.init_val_p(0)
    ,.max_step_p(1)
  ) out_credit_ctr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.down_i(returned_credit) // launch remote packet
    ,.up_i(launching_out) // receive credit back
    ,.count_o(out_credits_o)
  );


  assign returned_data_r_o     = return_packet_lo.data;
  assign returned_reg_id_r_o   = return_packet_lo.reg_id;
  assign returned_pkt_type_r_o = return_packet_lo.pkt_type;
  assign returned_v_r_o        = return_packet_v_lo & (return_packet_lo.pkt_type != e_return_credit);
  assign return_packet_yumi_li      = returned_yumi_i | (return_packet_v_lo & (return_packet_lo.pkt_type == e_return_credit));

  assign returned_credit_v_r_o      = returned_credit;
  assign returned_credit_reg_id_r_o = return_packet_lo.reg_id;






  //              //
  //  Assertions  //
  //              //

  // synopsys translate_off

  always_ff @ (negedge clk_i) begin
    if (~reset_i & return_packet_v_lo) begin
      assert({return_packet_lo.y_cord, return_packet_lo.x_cord} == {global_y_i, global_x_i})
        else begin
          $error("## errant credit packet v=%b for YX = %d,%d landed at YX=%d,%d (%m)",
            return_packet_v_lo,
            return_packet_lo.y_cord,
            return_packet_lo.x_cord,
            global_y_i, global_x_i);
          $finish();
        end
    end
  end

  always_ff @ (negedge clk_i) begin
    if ((returned_v_r_o === 1'b1) && (returned_yumi_i != 1'b1) && returned_fifo_full_o) begin
      $display("## Returned response will be dropped at YX=%d, %d (%m)", global_y_i, global_x_i);
      $finish();
    end
  end

  // synopsys translate_on

endmodule


