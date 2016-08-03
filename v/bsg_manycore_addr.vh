`define declare_bsg_manycore_addr_s(in_addr_width, in_x_cord_width, in_y_cord_width) \
   typedef struct packed {                                                           \
      logic       remote;                                                            \
      logic [(in_y_cord_width)-1:0] y_cord;                                          \
      logic [(in_x_cord_width)-1:0] x_cord;                                          \
      logic [((in_addr_width)-(in_y_cord_width)-(in_x_cord_width)-1-2)-1:0] addr;    \
      logic [1:0]                                                low_bits;           \
      } bsg_manycore_addr_s;
