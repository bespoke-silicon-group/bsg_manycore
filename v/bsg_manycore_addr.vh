`define declare_bsg_manycore_addr_s(epa_addr_width, max_x_cord_width, max_y_cord_width) \
   typedef struct packed {                                      \
      logic [1:0]       remote;                                 \
      logic [max_y_cord_width-1:0]       y_cord;                \
      logic [max_x_cord_width-1:0]       x_cord;                \
      logic [epa_addr_width-1:0]          addr;                  \
      logic [1:0]                        low_bits;              \
      } bsg_manycore_addr_s;

`define declare_bsg_manycore_dram_addr_s(dram_ch_addr_width)          \
   typedef struct packed {                                            \
      logic                                        is_dram_addr;      \
      logic [(32-1-2-dram_ch_addr_width)-1:0]      x_cord;            \
      logic [dram_ch_addr_width-1:0]               addr;              \
      logic [1:0]                                  low_bits;          \
      } bsg_manycore_dram_addr_s;
