/**
 *    bsg_manycore_xbar_fanin.v
 *
 */


`include "bsg_manycore_defines.vh"


module bsg_manycore_xbar_fanin
  import bsg_manycore_pkg::*;
  #(parameter `BSG_INV_PARAM(num_tiles_x_p)
    , `BSG_INV_PARAM(num_tiles_y_p)
    , `BSG_INV_PARAM(x_cord_width_p)
    , `BSG_INV_PARAM(y_cord_width_p)
    , `BSG_INV_PARAM(addr_width_p)
    , `BSG_INV_PARAM(data_width_p)
    , `BSG_INV_PARAM(fwd_not_rev_p)
  
    , parameter max_lock_count_p = 16
  
    , localparam num_in_lp = fwd_not_rev_p
                           ? (1+(num_tiles_x_p*num_tiles_y_p))
                           : (1+(num_tiles_x_p*num_tiles_y_p)+(2*num_tiles_x_p))
    , localparam packet_width_lp = fwd_not_rev_p
                                  ? `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
                                  : `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input [num_in_lp-1:0] v_i
    , input [num_in_lp-1:0][packet_width_lp-1:0] packet_i
    , output logic [num_in_lp-1:0] yumi_o

    , output logic v_o
    , output logic [packet_width_lp-1:0] packet_o
    , input ready_i
  );

  // Locking
  localparam count_width_lp = `BSG_WIDTH(max_lock_count_p);
  logic clear_li, up_li;
  logic [count_width_lp-1:0] count_lo;

  bsg_counter_clear_up #(
    .max_val_p(max_lock_count_p)
    ,.init_val_p(0)
    ,.disable_overflow_warning_p(1)
  ) cc0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.clear_i(clear_li)
    ,.up_i(up_li)
    ,.count_o(count_lo)
  );


  // round robin;
  logic [num_in_lp-1:0] rr_grants;
  logic [num_in_lp-1:0] grants_r, grants_n;
  logic rr_yumi_li;

  bsg_arb_round_robin #(
    .width_p(num_in_lp)
  ) rr (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.reqs_i(v_i)
    ,.grants_o(rr_grants)
    ,.yumi_i(rr_yumi_li)
  );


  // data mux
  logic [num_in_lp-1:0] mux_sel;

  bsg_mux_one_hot #(
    .els_p(num_in_lp)
    ,.width_p(packet_width_lp)
  ) mux0 (
    .data_i(packet_i)
    ,.sel_one_hot_i(mux_sel)
    ,.data_o(packet_o)
  );

  wire v_exist = |v_i;
  wire continue_lock = (v_i & grants_r) != '0;

  always_comb begin
    clear_li = 1'b0;
    up_li = 1'b0;
    rr_yumi_li = 1'b0;   
    grants_n = grants_r;
    mux_sel = '0;
    v_o = 1'b0;
    yumi_o = '0;

    if (count_lo == '0) begin
      v_o = v_exist;
      mux_sel = rr_grants;
      yumi_o = rr_grants & {num_in_lp{v_exist & ready_i}};
      if (v_exist & ready_i) begin
        up_li = 1'b1;
        rr_yumi_li = 1'b1;
        grants_n = rr_grants;
      end
    end
    else if (count_lo < max_lock_count_p) begin
      if (continue_lock) begin
        up_li = ready_i;
        rr_yumi_li = ready_i;
        mux_sel = grants_r;
        v_o = 1'b1;
        yumi_o = grants_r & {num_in_lp{ready_i}};
      end
      else begin
        if (v_exist) begin
          clear_li = ready_i;
          up_li = ready_i;
          rr_yumi_li = ready_i;
          grants_n = ready_i
            ? rr_grants
            : grants_r;
          mux_sel = rr_grants;
          yumi_o = rr_grants & {num_in_lp{ready_i}};
          v_o = 1'b1;
        end
        else begin
          clear_li = 1'b1;
        end
      end
    end
    else begin
      if (v_exist) begin
        v_o = 1'b1;
        clear_li = ready_i;
        up_li = ready_i;
        rr_yumi_li = ready_i;
        grants_n = ready_i
          ? rr_grants
          : grants_r;
        mux_sel = rr_grants;
        yumi_o = rr_grants & {num_in_lp{ready_i}};
      end
      else begin
        clear_li  = 1'b1;
      end
    end

  end


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      grants_r <= '0;
    end
    else begin
      grants_r <= grants_n;
    end
  end

  

endmodule

`BSG_ABSTRACT_MODULE(bsg_manycore_xbar_fanin)
