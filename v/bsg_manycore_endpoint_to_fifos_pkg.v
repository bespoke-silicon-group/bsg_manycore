`ifndef BSG_MANYCORE_ENDPOINT_TO_FIFOS_PKG_V
`define BSG_MANYCORE_ENDPOINT_TO_FIFOS_PKG_V


// To ease the programming, we slices the fields in the bsg_manycore_packet_s
// struct, and cast the fileds into multiple of bytes.
//
// assume 8 >= bsg_manycore_reg_id_width_gp
// assume 8 >= $bits(bsg_manycore_packet_op_e)
// assume 8 >= $bits(bsg_manycore_packet_op_ex_u)
// assume 8 >= $bits(bsg_manycore_return_packet_type_e)
`define declare_bsg_manycore_link_fifo_s(fifo_width_mp,addr_width_mp,data_width_mp,x_cord_width_mp,y_cord_width_mp) \
\
  typedef struct packed { \
    logic [fifo_width_mp-8-data_width_mp-8-y_cord_width_mp-x_cord_width_mp-1: \
    0]                            padding ; \
    logic [                8-1:0] pkt_type; \
    logic [    data_width_mp-1:0] data    ; \
    logic [                8-1:0] reg_id  ; \
    logic [  y_cord_width_mp-1:0] y_cord  ; \
    logic [  x_cord_width_mp-1:0] x_cord  ; \
  } bsg_mcl_response_s; \
\
  typedef union packed { \
    logic [data_width_mp-1:0] data     ; \
    logic [data_width_mp-1:0] load_info; \
  } bsg_mcl_packet_payload_u; \
\
  typedef struct packed { \
    logic [fifo_width_mp-addr_width_mp-3*8-data_width_mp-2*y_cord_width_mp-2*x_cord_width_mp-1: \
    0]                          padding   ; \
    logic [  addr_width_mp-1:0] addr      ; \
    logic [              8-1:0] op        ; \
    logic [              8-1:0] op_ex     ; \
    logic [              8-1:0] reg_id    ; \
    bsg_mcl_packet_payload_u    payload   ; \
    logic [y_cord_width_mp-1:0] src_y_cord; \
    logic [x_cord_width_mp-1:0] src_x_cord; \
    logic [y_cord_width_mp-1:0] y_cord    ; \
    logic [x_cord_width_mp-1:0] x_cord    ; \
  } bsg_mcl_request_s


package bsg_manycore_endpoint_to_fifos_pkg;

endpackage : bsg_manycore_endpoint_to_fifos_pkg

`endif // BSG_MANYCORE_ENDPOINT_TO_FIFOS_PKG_V
