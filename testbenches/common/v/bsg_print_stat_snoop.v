module bsg_print_stat_snoop
  import bsg_manycore_pkg::*;
  import bsg_manycore_addr_pkg::*;
  #(parameter data_width_p="inv"
    , parameter addr_width_p="inv"
    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , parameter link_sif_width_lp=
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)
    
  )
  (
    // manycore side
    input [link_sif_width_lp-1:0] loader_link_sif_in_i
    , input [link_sif_width_lp-1:0] loader_link_sif_out_i

    // snoop signals
    , output logic print_stat_v_o
    , output logic [data_width_p-1:0] print_stat_tag_o
  );

  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

  bsg_manycore_link_sif_s loader_link_sif_in;
  bsg_manycore_link_sif_s loader_link_sif_out;

  assign loader_link_sif_in = loader_link_sif_in_i;
  assign loader_link_sif_out = loader_link_sif_out_i;


  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);
  bsg_manycore_packet_s fwd_pkt;
  assign fwd_pkt = loader_link_sif_in.fwd.data;


  assign print_stat_v_o = loader_link_sif_in.fwd.v
    & (fwd_pkt.addr == (bsg_print_stat_epa_gp >> 2)) & loader_link_sif_out.fwd.ready_and_rev;
  assign print_stat_tag_o = fwd_pkt.payload.data;

  


  

endmodule
