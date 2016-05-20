`define bsg_manycore_packet_width(in_addr_width,in_data_width,in_x_cord_width,in_y_cord_width)\
    (2+(in_data_width >> 3)+(in_x_cord_width)+(in_y_cord_width)+(in_data_width)+(in_addr_width))

`define declare_bsg_manycore_packet_s(in_addr_width,in_data_width,in_x_cord_width,in_y_cord_width) \
   typedef struct packed {                    \
      logic [1:0] op;                         \
      logic [(in_data_width>>3)-1:0] op_ex;   \
      logic [(in_addr_width)-1:0] addr;       \
      logic [(in_data_width)-1:0] data;       \
      logic [(in_y_cord_width)-1:0] y_cord;   \
      logic [(in_x_cord_width)-1:0] x_cord;   \
   } bsg_manycore_packet_s

