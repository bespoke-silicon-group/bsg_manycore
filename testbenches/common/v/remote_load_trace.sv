/**
 *    remote_load_trace.v
 *
 *    this module traces remote load latencies for icache miss, float/integer remote load.
 *  
 *    When the remote load is launched, this module starts counting the number of cycles
 *    until the remote load response comes back and accepted by the core.
 */


// Bind this module to network_tx

// Trace format:
// {start_cycle},{end_cycle}{src_x},{src_y},{dest_x},{dest_y},{type},{latency}
//
// {start_cycle}  global_ctr when the packet is launched.  
// {end_cycle}    global_ctr when the response is received.
// {src_x/y}      x/y coord of the sender.
// {dest_x/y}     x/y cord destination of the packet.
// {type}         can be icache, float, or int (int includes atomic).
// {latency}      # of cycles to complete remote load. (end_cycle - start_cycle)

`include "bsg_manycore_defines.svh"
`include "profiler.svh"

module remote_load_trace
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  #(parameter `BSG_INV_PARAM(addr_width_p)
    , parameter `BSG_INV_PARAM(data_width_p)
    , parameter `BSG_INV_PARAM(x_cord_width_p)
    , parameter `BSG_INV_PARAM(y_cord_width_p)
    , parameter `BSG_INV_PARAM(pod_x_cord_width_p)
    , parameter `BSG_INV_PARAM(pod_y_cord_width_p)
    , parameter `BSG_INV_PARAM(num_tiles_x_p)
    , parameter `BSG_INV_PARAM(num_tiles_y_p)
    , parameter x_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter y_subcord_width_lp=`BSG_SAFE_CLOG2(num_tiles_y_p)

    , parameter `BSG_INV_PARAM(origin_x_cord_p)
    , parameter `BSG_INV_PARAM(origin_y_cord_p)

    , parameter packet_width_lp=
    `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
  )
  (
    input clk_i
    , input reset_i
  
    // packet going out
    , input remote_req_s remote_req_i
    , input out_v_o
    , input [packet_width_lp-1:0] out_packet_o


    // Load response coming back
    , input returned_v_i
    , input [RV32_reg_addr_width_gp-1:0] returned_reg_id_i
    , input bsg_manycore_return_packet_type_e returned_pkt_type_i
    , input returned_yumi_o


    // coord
    , input [x_subcord_width_lp-1:0] my_x_i
    , input [y_subcord_width_lp-1:0] my_y_i
    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i

    // ctrl signal
    , input trace_en_i
    , input [31:0] global_ctr_i
  );

  `DEFINE_PROFILER(remote_load_profiler
                   ,"remote_load_trace.csv"
                   ,"start_cycle,end_cycle,src_x,src_y,dest_x,dest_y,type,latency\n"
                   )

  wire [x_cord_width_p-1:0] global_x = {pod_x_i, my_x_i};
  wire [y_cord_width_p-1:0] global_y = {pod_y_i, my_y_i};

  // manycore packet
  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_packet_s out_packet;
  assign out_packet = out_packet_o;
  bsg_manycore_load_info_s load_info;
  assign load_info = out_packet.payload.load_info_s.load_info;


  // remote load status holding register
  typedef struct packed {
    logic [31:0] start_cycle;
    logic [x_cord_width_p-1:0] x_cord;
    logic [y_cord_width_p-1:0] y_cord;
  } remote_load_status_s;


  remote_load_status_s [RV32_reg_els_gp-1:0] int_rl_status_r;
  remote_load_status_s [RV32_reg_els_gp-1:0] float_rl_status_r;
  remote_load_status_s icache_status_r;

  wire int_rl_v    = out_v_o & (
    ((out_packet.op_v2 == e_remote_load) & ~load_info.icache_fetch & ~load_info.float_wb)
    | remote_req_i.is_amo_op);
  wire float_rl_v = out_v_o & (
    (out_packet.op_v2 == e_remote_load) & load_info.float_wb); 

  wire write_op_v = out_v_o & (
    ((out_packet.op_v2 == e_remote_store) |
     (out_packet.op_v2 == e_remote_sw)));

  wire icache_rl_v = out_v_o & (
    (out_packet.op_v2 == e_remote_load) & load_info.icache_fetch);
    
  logic [RV32_reg_els_gp-1:0] int_rl_we;
  logic [RV32_reg_els_gp-1:0] float_rl_we;

  bsg_decode_with_v #(
    .num_out_p(RV32_reg_els_gp)
  ) dv0 (
    .i(out_packet.reg_id)
    ,.v_i(int_rl_v)
    ,.o(int_rl_we)
  );

  bsg_decode_with_v #(
    .num_out_p(RV32_reg_els_gp)
  ) dv1 (
    .i(out_packet.reg_id)
    ,.v_i(float_rl_v)
    ,.o(float_rl_we)
  );

  remote_load_status_s next_rl;

  assign next_rl = '{
    start_cycle : global_ctr_i,
    x_cord      : out_packet.x_cord,
    y_cord      : out_packet.y_cord
  };


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      int_rl_status_r <= '0;
      float_rl_status_r <= '0;
      icache_status_r <= '0;
    end
    else begin
       
      for (integer i = 0 ; i < RV32_reg_els_gp; i++) begin
        if (int_rl_we[i])
          int_rl_status_r[i] <= next_rl;
        if (float_rl_we[i])
          float_rl_status_r[i] <= next_rl;
      end 

      if (icache_rl_v)
        icache_status_r <= next_rl;
    
    end
  end


  


  always @ (negedge clk_i) begin
    if (~reset_i & trace_en_i) begin

      // It is not currently possible to track the return of store
      // packets using reg_id, so we record store packets when they
      // depart.  While the caches respond in order, and we could use
      // this fact to determine the corresponding store packets in
      // post-processing that would require plumbing the
      // return_packet_lo.x/y_cord signals from
      // bsg_manycore_endpoint_standard and I'm not up for that much
      // of a change at the moment.
      if (write_op_v) begin
          $fwrite(remote_load_profiler_trace_fd(),"%0d,%s,%0d,%0d,%0d,%0d,%s,%s\n",
            global_ctr_i,
            "x",
            global_x,
            global_y,
            out_packet.x_cord,
            out_packet.y_cord,
            "write",
            "x"
          );
      end

      if (returned_v_i & returned_yumi_o) begin

        case (returned_pkt_type_i)

          e_return_int_wb: begin
            $fwrite(remote_load_profiler_trace_fd(),"%0d,%0d,%0d,%0d,%0d,%0d,%s,%0d\n",
              int_rl_status_r[returned_reg_id_i].start_cycle,
              global_ctr_i,
              global_x,
              global_y,
              int_rl_status_r[returned_reg_id_i].x_cord,
              int_rl_status_r[returned_reg_id_i].y_cord,
              "int",
              global_ctr_i-int_rl_status_r[returned_reg_id_i].start_cycle
            );   
          end

          e_return_float_wb: begin
            $fwrite(remote_load_profiler_trace_fd(),"%0d,%0d,%0d,%0d,%0d,%0d,%s,%0d\n",
              float_rl_status_r[returned_reg_id_i].start_cycle,
              global_ctr_i,
              global_x,
              global_y,
              float_rl_status_r[returned_reg_id_i].x_cord,
              float_rl_status_r[returned_reg_id_i].y_cord,
              "float",
              global_ctr_i-float_rl_status_r[returned_reg_id_i].start_cycle
            );   

          end
          e_return_ifetch: begin
            $fwrite(remote_load_profiler_trace_fd(),"%0d,%0d,%0d,%0d,%0d,%0d,%s,%0d\n",
              icache_status_r.start_cycle,
              global_ctr_i,
              global_x,
              global_y,
              icache_status_r.x_cord,
              icache_status_r.y_cord,
              "icache",
              global_ctr_i-icache_status_r.start_cycle
            );   

          end

        endcase

      end

    end
  end






endmodule

`BSG_ABSTRACT_MODULE(remote_load_trace)

