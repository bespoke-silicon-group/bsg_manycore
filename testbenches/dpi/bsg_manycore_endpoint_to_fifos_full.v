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
 *  bsg_manycore_endpoint_to_fifos_full.v
 *
 * Convert manycore packets into FIFO data streams, with fields aligned
 * to 8-bit/1-byte boundaries, or vice-versa.
 * 
 * Unlike bsg_manycore_endpoint_to_fifos, this module provides the
 * ability to send response packets
 *
 */

module bsg_manycore_endpoint_to_fifos_full
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
  , localparam reg_id_width_pad_lp = `BSG_CDIV(bsg_manycore_reg_id_width_gp,8)*8
  , parameter credit_counter_width_p = `BSG_WIDTH(32)
  , parameter ep_fifo_els_p = "inv"
  , parameter rev_fifo_els_p="inv" // for FIFO credit counting.

  , parameter link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  , parameter debug_p = 0
) (
  input                                      clk_i
  ,input                                      reset_i

  // manycore request
  ,output [                 fifo_width_p-1:0] mc_req_o
  ,output                                     mc_req_v_o
  ,input                                      mc_req_ready_i

  // endpoint request
  ,input  [                 fifo_width_p-1:0] endpoint_req_i
  ,input                                      endpoint_req_v_i
  ,output                                     endpoint_req_ready_o

  // manycore response
  ,output [                 fifo_width_p-1:0] mc_rsp_o
  ,output                                     mc_rsp_v_o
  ,input                                      mc_rsp_ready_i

  // endpoint response
  ,input  [                 fifo_width_p-1:0] endpoint_rsp_i
  ,input                                      endpoint_rsp_v_i
  ,output                                     endpoint_rsp_ready_o

  // manycore link
  ,input  [            link_sif_width_lp-1:0] link_sif_i
  ,output [            link_sif_width_lp-1:0] link_sif_o

  ,input  [               x_cord_width_p-1:0] global_x_i
  ,input  [               y_cord_width_p-1:0] global_y_i

  ,output [credit_counter_width_p-1:0] out_credits_used_o

);

  `declare_bsg_manycore_packet_aligned_s(fifo_width_p, addr_width_pad_lp, data_width_pad_lp, x_cord_width_pad_lp, y_cord_width_pad_lp);
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  // endpoint as master
  bsg_manycore_packet_aligned_s  endpoint_req_li_cast;
  bsg_manycore_return_packet_aligned_s mc_rsp_lo_cast;
  assign endpoint_req_li_cast = endpoint_req_i;
  assign mc_rsp_o             = mc_rsp_lo_cast;

  // manycore as master
  bsg_manycore_packet_aligned_s mc_req_lo_cast;
  bsg_manycore_return_packet_aligned_s endpoint_rsp_li_cast;
  assign mc_req_o = mc_req_lo_cast;
  assign endpoint_rsp_li_cast = endpoint_rsp_i;

  logic                         endpoint_in_v_lo;
  logic                         endpoint_in_yumi_li;
  logic [     data_width_p-1:0] endpoint_in_data_lo;
  logic [(data_width_p>>3)-1:0] endpoint_in_mask_lo;
  logic [     addr_width_p-1:0] endpoint_in_addr_lo;
  logic                         endpoint_in_we_lo;
  bsg_manycore_load_info_s      endpoint_in_load_info_lo;
  logic [   x_cord_width_p-1:0] in_src_x_cord_lo;
  logic [   y_cord_width_p-1:0] in_src_y_cord_lo;

  logic                                    returned_v_r_lo;
  logic                                    returned_yumi_li;
  logic                                    returned_fifo_full_lo;
  bsg_manycore_return_packet_type_e        returned_pkt_type_r_lo;
  logic [                data_width_p-1:0] returned_data_r_lo;
  wire  [bsg_manycore_reg_id_width_gp-1:0] returned_reg_id_r_lo;

  logic                 endpoint_out_v_li;
  bsg_manycore_packet_s endpoint_out_packet_li;
  logic                 endpoint_out_ready_lo;

  logic [data_width_p-1:0] returning_data_li;
  logic                    returning_v_li;

  // endpoint request to manycore
  // -------------------------
  assign endpoint_out_v_li = endpoint_req_v_i; // TODO: Used to be masked by credits, should be checked by host
  assign endpoint_req_ready_o = endpoint_out_ready_lo; // TODO: used to be masked by credits, should be checked by host.

  assign endpoint_out_packet_li.addr       = addr_width_p'(endpoint_req_li_cast.addr);
  assign endpoint_out_packet_li.op_v2      = bsg_manycore_packet_op_e'(endpoint_req_li_cast.op_v2);
  assign endpoint_out_packet_li.reg_id     = bsg_manycore_reg_id_width_gp'(endpoint_req_li_cast.reg_id);
  assign endpoint_out_packet_li.src_y_cord = y_cord_width_p'(endpoint_req_li_cast.src_y_cord);
  assign endpoint_out_packet_li.src_x_cord = x_cord_width_p'(endpoint_req_li_cast.src_x_cord);
  assign endpoint_out_packet_li.y_cord     = y_cord_width_p'(endpoint_req_li_cast.y_cord);
  assign endpoint_out_packet_li.x_cord     = x_cord_width_p'(endpoint_req_li_cast.x_cord);
  assign endpoint_out_packet_li.payload.data = endpoint_req_li_cast.payload.data;

  // synopsys translate_off
  always @(posedge clk_i) begin
    if (debug_p & endpoint_out_v_li) begin
      $display("bsg_manycore_endpoint_to_fifos: op_v2=%d", endpoint_out_packet_li.op_v2);
      $display("bsg_manycore_endpoint_to_fifos: addr=%h", endpoint_out_packet_li.addr);
      $display("bsg_manycore_endpoint_to_fifos: data=%h", endpoint_out_packet_li.payload.data);
      $display("bsg_manycore_endpoint_to_fifos: reg_id=%h", endpoint_out_packet_li.reg_id);
      $display("bsg_manycore_endpoint_to_fifos: x_cord=%d", endpoint_out_packet_li.x_cord);
      $display("bsg_manycore_endpoint_to_fifos: y_cord=%d", endpoint_out_packet_li.y_cord);
      $display("bsg_manycore_endpoint_to_fifos: src_x_cord=%d", endpoint_out_packet_li.src_x_cord);
      $display("bsg_manycore_endpoint_to_fifos: src_y_cord=%d", endpoint_out_packet_li.src_y_cord);
    end
  end

  always @(posedge clk_i) begin
    if (debug_p & mc_rsp_v_o & mc_rsp_ready_i) begin
      $display("bsg_manycore_endpoint_to_fifos (response): type=%s", returned_pkt_type_r_lo.name());
      $display("bsg_manycore_endpoint_to_fifos (response): data=%h", mc_rsp_lo_cast.data);
      $display("bsg_manycore_endpoint_to_fifos (response): reg_id=%h", mc_rsp_lo_cast.reg_id);
    end
  end
  // synopsys translate_on

  // manycore response to endpoint
  // -------------------------
  assign mc_rsp_v_o = returned_v_r_lo;
  assign returned_yumi_li = mc_rsp_ready_i & mc_rsp_v_o;

  assign mc_rsp_lo_cast.padding  = '0;
  assign mc_rsp_lo_cast.pkt_type = 8'(returned_pkt_type_r_lo);
  assign mc_rsp_lo_cast.data     = data_width_pad_lp'(returned_data_r_lo);
  assign mc_rsp_lo_cast.reg_id   = 8'(returned_reg_id_r_lo);
  assign mc_rsp_lo_cast.y_cord   = y_cord_width_pad_lp'(global_y_i);
  assign mc_rsp_lo_cast.x_cord   = x_cord_width_pad_lp'(global_x_i);

  // manycore request to endpoint
  // -------------------------
  assign mc_req_v_o = endpoint_in_v_lo;
  assign endpoint_in_yumi_li = mc_req_ready_i & mc_req_v_o;

  assign mc_req_lo_cast.padding      = '0;
  assign mc_req_lo_cast.addr         = addr_width_pad_lp'(endpoint_in_addr_lo);
  assign mc_req_lo_cast.op_v2        = ~endpoint_in_we_lo ? e_remote_load : 
                                       (endpoint_in_mask_lo == 4'b1111) ? e_remote_sw : e_remote_store;
  assign mc_req_lo_cast.payload.data = data_width_p'(endpoint_in_data_lo);
  assign mc_req_lo_cast.src_y_cord   = y_cord_width_pad_lp'(in_src_y_cord_lo);
  assign mc_req_lo_cast.src_x_cord   = x_cord_width_pad_lp'(in_src_x_cord_lo);
  assign mc_req_lo_cast.y_cord       = y_cord_width_pad_lp'(global_y_i);
  assign mc_req_lo_cast.x_cord       = x_cord_width_pad_lp'(global_x_i);
  assign mc_req_lo_cast.reg_id       = 8'(endpoint_in_mask_lo); // TODO: This is needed for writes, but is not correct for reads

  // endpoint response to manycore
  // -------------------------
  assign returning_data_li = data_width_p'(endpoint_rsp_li_cast.data);
  assign returning_v_li = endpoint_rsp_v_i;

  // TODO: Not sure this is right. There is no returning_ready.
  assign endpoint_rsp_ready_o = '1;

  bsg_manycore_endpoint_standard #(
    .x_cord_width_p(x_cord_width_p)
    ,.y_cord_width_p(y_cord_width_p)
    ,.fifo_els_p(ep_fifo_els_p)
    ,.addr_width_p(addr_width_p)
    ,.data_width_p(data_width_p)
    ,.credit_counter_width_p(credit_counter_width_p)
    ,.rev_fifo_els_p(rev_fifo_els_p)
    ,.debug_p(0)
  ) epsd (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_sif_i(link_sif_i)
    ,.link_sif_o(link_sif_o)

    // manycore packet -> fifo
    ,.in_v_o(endpoint_in_v_lo)
    ,.in_yumi_i(endpoint_in_yumi_li)
    ,.in_data_o(endpoint_in_data_lo)
    ,.in_mask_o(endpoint_in_mask_lo)
    ,.in_addr_o(endpoint_in_addr_lo)
    ,.in_we_o(endpoint_in_we_lo)
    ,.in_load_info_o(endpoint_in_load_info_lo)
    ,.in_src_x_cord_o(in_src_x_cord_lo)
    ,.in_src_y_cord_o(in_src_y_cord_lo)

    // fifo -> manycore packet
    ,.out_v_i(endpoint_out_v_li)
    ,.out_packet_i(endpoint_out_packet_li)
    ,.out_credit_or_ready_o(endpoint_out_ready_lo)

    // manycore response -> endpoint fifo
    ,.returned_data_r_o(returned_data_r_lo)
    ,.returned_reg_id_r_o(returned_reg_id_r_lo)
    ,.returned_v_r_o(returned_v_r_lo)
    ,.returned_pkt_type_r_o(returned_pkt_type_r_lo)
    ,.returned_yumi_i(returned_yumi_li)
    ,.returned_fifo_full_o(returned_fifo_full_lo)

    // endpoint fifo -> manycore network
    ,.returning_data_i(returning_data_li)
    ,.returning_v_i(returning_v_li)

    ,.out_credits_used_o(out_credits_used_o)

    ,.global_x_i(global_x_i)
    ,.global_y_i(global_y_i)
  );

  // Assert if the endpoint doesn't respond to read and write requests
  // on the next cycle.

  // synopsys translate_off
  logic expected_returning_r;
  always_ff @(posedge clk_i) begin
    if(reset_i)
      expected_returning_r <= '0;
    else
      expected_returning_r <= endpoint_in_yumi_li & ~endpoint_in_we_lo;
  end

  always_ff @(negedge clk_i) begin
        if( (expected_returning_r === 1'b1) && ( returning_v_li != 1'b1) ) begin
                $error("## Endpoint must respond to all requests on next cycle (%d, %d)", global_y_i, global_x_i);
                //$finish();
        end
  end
  // synopsys translate_on

endmodule
