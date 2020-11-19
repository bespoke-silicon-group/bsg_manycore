// bsg_nonsynth_dpi_manycore_tile is a drop-in, non-synthesizable
// socket for emulating a tile (or accelerator) using C/C++ functions.
//
// bsg_nonsynth_dpi_manycore_tile can be instantiated using '9' in the
// hetero_type_vec_p parameter at the top level of the simulation
// testbenches, which is usually exposed in the
// Makefile.machine.include file.
//
// Users emulate a tile by writing two C/C++ functions:
//
//    bsg_dpi_tile_init(): a function that is called ONCE during
//    initialization and takes four arguments (num_tiles_y_p,
//    num_tiles_x_p, my_y_i, and my_x_i)

//    bsg_dpi_tile(): a function that is called on each cycle, with
//    and takes four packet interfaces as arguments (network_req,
//    network_rsp, endpoint_req, endpoint_rsp)
//
// This allows users to send and recieve packets. Higher-level
// interfaces can be built in C/C++, and potentially, Python.

module bsg_nonsynth_dpi_manycore_tile
   import bsg_manycore_pkg::*;
   import bsg_vanilla_pkg::*;
   import bsg_bladerunner_pkg::*;
   #(parameter x_cord_width_p = "inv"
     , parameter y_cord_width_p = "inv"
     , parameter pod_x_cord_width_p = "inv"
     , parameter pod_y_cord_width_p = "inv"
     , parameter data_width_p = "inv"
     , parameter addr_width_p = "inv"

     , parameter icache_tag_width_p = "inv"
     , parameter icache_entries_p = "inv"

     , parameter dmem_size_p = "inv"
     , parameter vcache_size_p = "inv"
     , parameter vcache_block_size_in_words_p="inv"
     , parameter vcache_sets_p = "inv"

     , parameter num_tiles_x_p="inv"
     , parameter num_tiles_y_p="inv"

     , parameter x_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
     , parameter y_subcord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p)

     , parameter fwd_fifo_els_p="inv" // for FIFO credit counting.
     , parameter rev_fifo_els_p="inv" // for FIFO credit counting.

     , parameter credit_counter_width_p = `BSG_WIDTH(32)
     , parameter proc_fifo_els_p = 4
     , parameter debug_p = 1


     , parameter branch_trace_en_p = 0

     , parameter icache_addr_width_lp = `BSG_SAFE_CLOG2(icache_entries_p)
     , parameter dmem_addr_width_lp = `BSG_SAFE_CLOG2(dmem_size_p)
     , parameter pc_width_lp=(icache_addr_width_lp+icache_tag_width_p)
     , parameter data_mask_width_lp=(data_width_p>>3)
     , parameter reg_addr_width_lp=RV32_reg_addr_width_gp

     , parameter link_sif_width_lp =
     `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p)

     )
   (
    input clk_i
    , input reset_i

    , input [link_sif_width_lp-1:0] link_sif_i
    , output logic [link_sif_width_lp-1:0] link_sif_o

    // subcord within a pod
    , input [x_subcord_width_lp-1:0] my_x_i
    , input [y_subcord_width_lp-1:0] my_y_i

    // pod coordinate
    , input [pod_x_cord_width_p-1:0] pod_x_i
    , input [pod_y_cord_width_p-1:0] pod_y_i
    );

   localparam fifo_width_lp = 128;

   // endpoint standard
   `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p);

   logic [credit_counter_width_p-1:0] out_credits_used_lo;
   
   // Endpoint -> Manycore Requests
   logic [fifo_width_lp-1:0]           endpoint_req_data_lo;
   logic                               endpoint_req_v_lo;
   logic                               endpoint_req_ready_li;

   // Endpoint -> Manycore Responses
   logic [fifo_width_lp-1:0]           endpoint_rsp_data_lo;
   logic                               endpoint_rsp_v_lo;
   logic                               endpoint_rsp_ready_li;

   // Manycore -> Endpoint Responses
   logic [fifo_width_lp-1:0]           mc_rsp_data_li;
   logic                               mc_rsp_v_li;
   logic                               mc_rsp_ready_lo;

   // Manycore -> Endpoint Requests
   logic [fifo_width_lp-1:0]           mc_req_data_li;
   logic                               mc_req_v_li;
   logic                               mc_req_ready_lo;

   bsg_manycore_endpoint_to_fifos
     #(
       .fifo_width_p(fifo_width_lp)
       ,.x_cord_width_p(x_cord_width_p)
       ,.y_cord_width_p(y_cord_width_p)
       ,.addr_width_p(addr_width_p)
       ,.data_width_p(data_width_p)
       ,.ep_fifo_els_p(proc_fifo_els_p)
       ,.rev_fifo_els_p(rev_fifo_els_p)

       ,.credit_counter_width_p(credit_counter_width_p)
       )
   mc_ep_to_fifos
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      // fifo interfaces
      ,.mc_req_o(mc_req_data_li)
      ,.mc_req_v_o(mc_req_v_li)
      ,.mc_req_ready_i(mc_req_ready_lo)

      ,.endpoint_req_i(endpoint_req_data_lo)
      ,.endpoint_req_v_i(endpoint_req_v_lo)
      ,.endpoint_req_ready_o(endpoint_req_ready_li)

      ,.mc_rsp_o(mc_rsp_data_li)
      ,.mc_rsp_v_o(mc_rsp_v_li)
      ,.mc_rsp_ready_i(mc_rsp_ready_lo)

      ,.endpoint_rsp_i(endpoint_rsp_data_lo)
      ,.endpoint_rsp_v_i(endpoint_rsp_v_lo)
      ,.endpoint_rsp_ready_o(endpoint_rsp_ready_li)

      // manycore link
      ,.link_sif_i(link_sif_i)
      ,.link_sif_o(link_sif_o)
      ,.my_x_i({pod_x_i, my_x_i})
      ,.my_y_i({pod_y_i, my_y_i})
      ,.out_credits_used_o(out_credits_used_lo)
      );

   // Always drain incoming packets
   assign mc_rsp_ready_lo = '1;
   assign mc_req_ready_lo = '1;

   logic                               next_endpoint_req_v_lo;
   logic [fifo_width_lp-1:0]           next_endpoint_req_data_lo;

   logic                               next_endpoint_rsp_v_lo;
   logic [fifo_width_lp-1:0]           next_endpoint_rsp_data_lo;

   always_ff @(posedge clk_i) begin
      endpoint_rsp_v_lo <= next_endpoint_rsp_v_lo;
      endpoint_rsp_data_lo <= next_endpoint_rsp_data_lo;
   end

   // Track tile initialization. Each tile should initialized
   // separately to give the tile the opportunity to initialize its own
   // datastructures or custom "configuration"
   logic                               init_r = 0;
   always_ff @(negedge clk_i) begin
      // Set defaults
      endpoint_req_v_lo = 0;
      endpoint_req_data_lo = '0;

      next_endpoint_rsp_v_lo = 0;
      next_endpoint_rsp_data_lo = '0;

      if(!reset_i) begin
         if(!init_r) begin
            init_r <= 1;
            bsg_dpi_tile_init(num_tiles_y_p,
                              num_tiles_x_p,
                              y_cord_width_p,
                              x_cord_width_p,
                              pod_y_cord_width_p,
                              pod_x_cord_width_p,

                              icache_entries_p,
                              dmem_size_p * 4, // Despite what it implies, dmem_size_p is actually entries, not bytes
                              addr_width_p,
                              data_width_p,

                              (1 << bsg_manycore_reg_id_width_gp),
                              credit_counter_width_p,

                              vcache_sets_p,
                              vcache_block_size_in_words_p,
                              bsg_machine_llcache_stripe_words_gp, // From bsg_bladerunner_pkg.v

                              bsg_machine_io_coord_x_gp,
                              bsg_machine_io_coord_y_gp,

                              {pod_x_i, my_x_i},
                              {pod_y_i, my_y_i});
         end else begin
            bsg_dpi_tile(
                         {pod_x_i, my_x_i},
                         {pod_y_i, my_y_i},
                         out_credits_used_lo,
                         mc_req_v_li,
                         mc_req_data_li,
                         next_endpoint_rsp_v_lo,
                         next_endpoint_rsp_data_lo,
                         endpoint_rsp_ready_li,
                         mc_rsp_v_li,
                         mc_rsp_data_li,
                         endpoint_req_v_lo,
                         endpoint_req_data_lo,
                         endpoint_req_ready_li);
         end
      end
   end

   // Initialize the C/C++ manycore tile using parameters from
   // simulation. Additional parameters can be
   // passed through this interface if necessary.
   import "DPI" function void bsg_dpi_tile_init(input int num_tiles_y_p
                                                ,input int num_tiles_x_p

                                                ,input int machine_coord_width_y_p
                                                ,input int machine_coord_width_x_p
                                                ,input int pod_coord_width_y_p
                                                ,input int pod_coord_width_x_p

                                                ,input int icache_entries_p
                                                ,input int dmem_size_p
                                                ,input int addr_width_p
                                                ,input int data_width_p

                                                ,input int max_reg_id
                                                ,input int credit_counter_width_p

                                                ,input int vcache_sets_p
                                                ,input int vcache_block_words_p
                                                ,input int vcache_stripe_words_p

                                                ,input int host_x_i
                                                ,input int host_y_i
                                                ,input int my_x_i
                                                ,input int my_y_i);

   // Emulate a single cycle of the C/C++ manycore tile, and present
   // all of the network interfaces. Network requests (network_req_i)
   // must be read when they are available (network_req_v_i == 1), and
   // a response must be sent on the same cycle (this RTL module
   // handles the timing). Network responses (network_rsp_o) must also
   // be read when they are available (network_rsp_v_o == 1).
   import "DPI" function void bsg_dpi_tile(input int                      my_x_i
                                           ,input int                      my_y_i

                                           ,input int                      network_req_credits_used_i

                                           ,input bit                      network_req_v_i
                                           ,input bit [fifo_width_lp-1:0]  network_req_i

                                           ,output bit                     endpoint_rsp_v_o
                                           ,output bit [fifo_width_lp-1:0] endpoint_rsp_o
                                           ,input bit                      endpoint_rsp_ready_i

                                           ,input bit                      network_rsp_v_i
                                           ,input bit [fifo_width_lp-1:0]  network_rsp_i

                                           ,output bit                     endpoint_req_v_o
                                           ,output bit [fifo_width_lp-1:0] endpoint_req_o
                                           ,input bit                      endpoint_req_ready_i
                                           );

   import "DPI" function void bsg_dpi_tile_finish(input int                      my_x_i
                                                  ,input int                     my_y_i);


   final begin
      bsg_dpi_tile_finish({pod_x_i, my_x_i}, {pod_y_i, my_y_i});
   end

endmodule
