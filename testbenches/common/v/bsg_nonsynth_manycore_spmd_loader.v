/**
 *  bsg_nonsynth_manycore_spmd_loader.v
 *
 */


module bsg_nonsynth_manycore_spmd_loader
  import bsg_manycore_pkg::*;
  #(parameter addr_width_p="inv"
    , parameter data_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter x_cord_width_p="inv"

    , parameter packet_width_lp =
      `bsg_manycore_packet_width(addr_width_p,data_width_p,
        x_cord_width_p,y_cord_width_p)

    , parameter max_nbf_p = 2**20
    , parameter nbf_addr_width_lp = `BSG_SAFE_CLOG2(max_nbf_p)
  )
  ( 
    input clk_i
    , input reset_i
    , output done_o

    , output [packet_width_lp-1:0] packet_o
    , output logic v_o
    , input ready_i

    , input [y_cord_width_p-1:0] my_y_i
    , input [x_cord_width_p-1:0] my_x_i
  );

  // manycore packet
  //
  typedef struct packed {
    logic [7:0] x_cord;
    logic [7:0] y_cord;
    logic [31:0] epa;
    logic [31:0] data;
  } bsg_nbf_s;

  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,
    x_cord_width_p,y_cord_width_p);

  bsg_manycore_packet_s packet;

  assign packet_o = packet;



  // read nbf file.
  //
  logic [79:0] nbf [max_nbf_p-1:0];
  logic [nbf_addr_width_lp-1:0] nbf_addr_r, nbf_addr_n;
  bsg_nbf_s curr_nbf;
  assign curr_nbf = nbf[nbf_addr_r];

  assign packet.addr = curr_nbf.epa[0+:addr_width_p];
  assign packet.op = e_remote_store;
  assign packet.op_ex = 4'b1111;
  assign packet.payload = curr_nbf.data;
  assign packet.src_y_cord = my_y_i;
  assign packet.src_x_cord = my_x_i;
  assign packet.y_cord = curr_nbf.y_cord[0+:y_cord_width_p];
  assign packet.x_cord = curr_nbf.x_cord[0+:x_cord_width_p];
  assign packet.reg_id = '0;

  integer status;
  string nbf_file;
  initial begin
    status = $value$plusargs("nbf_file=%s", nbf_file);
    $readmemh(nbf_file, nbf);
  end

  logic loader_done_r, loader_done_n;
  assign done_o = loader_done_r;
 
  always_comb begin
    if (reset_i) begin
      v_o = 1'b0;
      nbf_addr_n = nbf_addr_r;
      loader_done_n = 1'b0;
    end
    else begin
      if (&nbf[nbf_addr_r]) begin // the last line in nbf should be "ff ff ffffffff ffffffff".
        v_o = 1'b0;
        nbf_addr_n = nbf_addr_r;
        loader_done_n = 1'b1;
      end
      else begin
        v_o = 1'b1;
        nbf_addr_n = ready_i
          ? nbf_addr_r + 1
          : nbf_addr_r;
        loader_done_n = 1'b0;
      end
    end
  end
  
  logic loader_done;
  assign loader_done = ~loader_done_r & loader_done_n;

  always_ff @ (negedge clk_i) begin
    if (~reset_i) begin
      if (loader_done)
        $display("[BSG_INFO][SPMD_LOADER] SPMD loader finished loading. t=%0t", $time);
  
      if (v_o & ready_i)
        $display("[BSG_INFO][SPMD_LOADER] sending packet #%0d. x,y=%0d,%0d, addr=%x, data=%x, t=%0t",
          nbf_addr_r,
          packet.x_cord, packet.y_cord,
          packet.addr,
          packet.payload,
          $time
        );
    end
      
  end
 

  // sequential
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      nbf_addr_r <= '0;
      loader_done_r <= 1'b0;
    end
    else begin
      nbf_addr_r <= nbf_addr_n;
      loader_done_r <= loader_done_n;
    end
  end

endmodule
