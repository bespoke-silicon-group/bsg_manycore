`define declare_bsg_manycore_addr_s(in_addr_width, in_x_cord_width, in_y_cord_width) \
   typedef struct packed {                                                           \
      logic       remote;                                                            \
      logic [y_cord_width_p-1:0] y_cord;                                             \
      logic [x_cord_width_p-1:0] x_cord;                                             \
      logic [(addr_width_p-y_cord_width_p-x_cord_width_p-1)-1:0] addr;               \
      } addr_decode_s;
