// Copyright (c) 2019, University of Washington All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// Neither the name of the copyright holder nor the names of its contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
// ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

/*
*  bsg_manycore_endpoint_to_fifos.v
*
* Convert the tx_fifo data stream into manycore packet
* Or cast the manycore packet to the rx_fifo data stream
*/

module bsg_manycore_endpoint_to_fifos
  import bsg_manycore_pkg::*;
#(
  parameter fifo_width_p = "inv"
  // these are endpoint parameters
  , parameter x_cord_width_p = "inv"
  , localparam x_cord_width_pad_lp = `BSG_CDIV(x_cord_width_p,8)*8
  , parameter y_cord_width_p = "inv"
  , localparam y_cord_width_pad_lp = `BSG_CDIV(y_cord_width_p,8)*8
  , parameter addr_width_p = "inv"
  , localparam addr_width_pad_lp = `BSG_CDIV(addr_width_p,8)*8
  , parameter data_width_p = "inv"
  , localparam data_width_pad_lp = `BSG_CDIV(data_width_p,8)*8
  , parameter max_out_credits_p = "inv"
  , parameter ep_fifo_els_p = "inv"
  , parameter link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
) (
  input                                      clk_i
  ,input                                      reset_i

  // manycore request
  ,output [                 fifo_width_p-1:0] mc_req_o
  ,output                                     mc_req_v_o
  ,input                                      mc_req_ready_i

  // host request
  ,input  [                 fifo_width_p-1:0] host_req_i
  ,input                                      host_req_v_i
  ,output                                     host_req_ready_o

  // manycore response
  ,output [                 fifo_width_p-1:0] mc_rsp_o
  ,output                                     mc_rsp_v_o
  ,input                                      mc_rsp_ready_i

  // host does not return data to the manycore

  // manycore link
  ,input  [            link_sif_width_lp-1:0] link_sif_i
  ,output [            link_sif_width_lp-1:0] link_sif_o
  ,input  [               x_cord_width_p-1:0] my_x_i
  ,input  [               y_cord_width_p-1:0] my_y_i

  ,output [`BSG_WIDTH(max_out_credits_p)-1:0] out_credits_o

);

  `declare_bsg_manycore_link_fifo_s(fifo_width_p, addr_width_pad_lp, data_width_pad_lp, x_cord_width_pad_lp, y_cord_width_pad_lp);

  // host as master
  bsg_mcl_request_s  host_req_li_cast;
  bsg_mcl_response_s mc_rsp_lo_cast  ;
  assign host_req_li_cast = host_req_i;
  assign mc_rsp_o         = mc_rsp_lo_cast;


  // manycore as master
  bsg_mcl_request_s mc_req_lo_cast;
  assign mc_req_o = mc_req_lo_cast;


  // manycore endpoint signals
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  logic                         endpoint_in_v_lo   ;
  logic                         endpoint_in_yumi_li;
  logic [     data_width_p-1:0] endpoint_in_data_lo;
  logic [(data_width_p>>3)-1:0] endpoint_in_mask_lo;
  logic [     addr_width_p-1:0] endpoint_in_addr_lo;
  logic                         endpoint_in_we_lo  ;
  logic [   x_cord_width_p-1:0] in_src_x_cord_lo   ;
  logic [   y_cord_width_p-1:0] in_src_y_cord_lo   ;

  logic                                    returned_v_r_lo       ;
  logic                                    returned_yumi_li      ;
  logic                                    returned_fifo_full_lo ;
  bsg_manycore_return_packet_type_e        returned_pkt_type_r_lo;
  logic [                data_width_p-1:0] returned_data_r_lo    ;
  wire  [bsg_manycore_reg_id_width_gp-1:0] returned_reg_id_r_lo  ;

  logic                 endpoint_out_v_li     ;
  bsg_manycore_packet_s endpoint_out_packet_li;
  logic                 endpoint_out_ready_lo ;

  logic [data_width_p-1:0] returning_data_li;
  logic                    returning_v_li   ;


  // host request to manycore
  // -------------------------
  assign endpoint_out_v_li = ~(out_credits_o == 0) & host_req_v_i;
  assign host_req_ready_o  = ~(out_credits_o == 0) & endpoint_out_ready_lo;

  assign endpoint_out_packet_li.addr       = addr_width_p'(host_req_li_cast.addr);
  assign endpoint_out_packet_li.op         = bsg_manycore_packet_op_e'(host_req_li_cast.op);
  assign endpoint_out_packet_li.op_ex      = bsg_manycore_packet_op_ex_u'(host_req_li_cast.op_ex);
  assign endpoint_out_packet_li.reg_id     = bsg_manycore_reg_id_width_gp'(host_req_li_cast.reg_id);
  assign endpoint_out_packet_li.src_y_cord = y_cord_width_p'(host_req_li_cast.src_y_cord);
  assign endpoint_out_packet_li.src_x_cord = x_cord_width_p'(host_req_li_cast.src_x_cord);
  assign endpoint_out_packet_li.y_cord     = y_cord_width_p'(host_req_li_cast.y_cord);
  assign endpoint_out_packet_li.x_cord     = x_cord_width_p'(host_req_li_cast.x_cord);

  always_comb begin
    if (endpoint_out_packet_li.op == e_remote_store) begin
      endpoint_out_packet_li.payload.data = host_req_li_cast.payload.data;
    end
    else begin
      endpoint_out_packet_li.payload.load_info_s.load_info.float_wb       = 1'b0;
      endpoint_out_packet_li.payload.load_info_s.load_info.icache_fetch   = 1'b0;
      endpoint_out_packet_li.payload.load_info_s.load_info.part_sel       = 4'b1111;
      endpoint_out_packet_li.payload.load_info_s.load_info.is_unsigned_op = 1'b1;
      endpoint_out_packet_li.payload.load_info_s.load_info.is_byte_op     = 1'b0;
      endpoint_out_packet_li.payload.load_info_s.load_info.is_hex_op      = 1'b0;
    end
  end

  always_ff @(negedge clk_i) begin
    if (endpoint_out_v_li)
      assert(endpoint_out_packet_li.op != e_remote_amo) else
        $error("[BSG_ERROR][%m] remote atomic memory operations from the host are not supported.");
  end


  // manycore response to host
  // -------------------------
  assign mc_rsp_v_o = returned_v_r_lo;
  assign returned_yumi_li = mc_rsp_ready_i & mc_rsp_v_o;

  assign mc_rsp_lo_cast.padding  = '0;
  assign mc_rsp_lo_cast.pkt_type = 8'(returned_pkt_type_r_lo);
  assign mc_rsp_lo_cast.data     = data_width_pad_lp'(returned_data_r_lo);
  assign mc_rsp_lo_cast.reg_id   = 8'(returned_reg_id_r_lo);
  assign mc_rsp_lo_cast.y_cord   = y_cord_width_pad_lp'(my_y_i);
  assign mc_rsp_lo_cast.x_cord   = x_cord_width_pad_lp'(my_x_i);


  // manycore request to host
  // -------------------------
  assign mc_req_v_o = endpoint_in_v_lo;
  assign endpoint_in_yumi_li = mc_req_ready_i & mc_req_v_o;

  assign mc_req_lo_cast.padding      = '0;
  assign mc_req_lo_cast.addr         = addr_width_pad_lp'(endpoint_in_addr_lo);
  assign mc_req_lo_cast.op           = 8'(endpoint_in_we_lo);
  assign mc_req_lo_cast.op_ex        = 8'(endpoint_in_mask_lo);
  assign mc_req_lo_cast.payload.data = data_width_p'(endpoint_in_data_lo);
  assign mc_req_lo_cast.src_y_cord   = y_cord_width_pad_lp'(in_src_y_cord_lo);
  assign mc_req_lo_cast.src_x_cord   = x_cord_width_pad_lp'(in_src_x_cord_lo);
  assign mc_req_lo_cast.y_cord       = y_cord_width_pad_lp'(my_y_i);
  assign mc_req_lo_cast.x_cord       = x_cord_width_pad_lp'(my_x_i);


  // host response to manycore
  // -------------------------

  // delay 1 cycle to response to the manycore remote write, as per the doc
  logic returning_wr_v_r;
  always_ff @(posedge clk_i) begin
    if(reset_i)
      returning_wr_v_r <= '0;
    else
      returning_wr_v_r <= endpoint_in_yumi_li & endpoint_in_we_lo;
  end

  assign returning_data_li = '0;  // returning data is zero by default
  assign returning_v_li    = returning_wr_v_r;


  bsg_manycore_endpoint_standard #(
    .x_cord_width_p   (x_cord_width_p      ),
    .y_cord_width_p   (y_cord_width_p      ),
    .fifo_els_p       (ep_fifo_els_p       ),
    .addr_width_p     (addr_width_p        ),
    .data_width_p     (data_width_p        ),
    .max_out_credits_p(max_out_credits_p   )
  ) epsd (
    .clk_i                (clk_i                 ),
    .reset_i              (reset_i               ),

    .link_sif_i           (link_sif_i            ),
    .link_sif_o           (link_sif_o            ),

    // manycore packet -> fifo
    .in_v_o               (endpoint_in_v_lo      ),
    .in_yumi_i            (endpoint_in_yumi_li   ),
    .in_data_o            (endpoint_in_data_lo   ),
    .in_mask_o            (endpoint_in_mask_lo   ),
    .in_addr_o            (endpoint_in_addr_lo   ),
    .in_we_o              (endpoint_in_we_lo     ),
    .in_load_info_o       (                      ), // not used because the manycore will not issue read requests to the host
    .in_src_x_cord_o      (in_src_x_cord_lo      ),
    .in_src_y_cord_o      (in_src_y_cord_lo      ),

    // fifo -> manycore packet
    .out_v_i              (endpoint_out_v_li     ),
    .out_packet_i         (endpoint_out_packet_li),
    .out_ready_o          (endpoint_out_ready_lo ),

    // manycore credit -> fifo
    .returned_data_r_o    (returned_data_r_lo    ),
    .returned_reg_id_r_o  (returned_reg_id_r_lo  ),
    .returned_v_r_o       (returned_v_r_lo       ),
    .returned_pkt_type_r_o(returned_pkt_type_r_lo),
    .returned_yumi_i      (returned_yumi_li      ),
    .returned_fifo_full_o (returned_fifo_full_lo ),

    // fifo -> manycore credit
    .returning_data_i     (returning_data_li     ),
    .returning_v_i        (returning_v_li        ),

    .out_credits_o        (out_credits_o         ),
    .my_x_i               (my_x_i                ),
    .my_y_i               (my_y_i                )
  );

endmodule
