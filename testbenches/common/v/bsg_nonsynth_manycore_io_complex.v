`include "bsg_manycore_packet.vh"

// currently only supports south side of chip

module bsg_nonsynth_manycore_io_complex
  #(parameter icache_entries_num_p = "inv"
    , parameter max_cycles_p = "inv"
    , parameter addr_width_p = "inv"
    , parameter load_id_width_p = "inv"
    , parameter epa_byte_addr_width_p = "inv"
    , parameter dram_ch_num_p = 0
    , parameter dram_ch_addr_width_p=-1
    , parameter data_width_p  = 32
    , parameter num_tiles_x_p = "inv"
    , parameter num_tiles_y_p = "inv"
    , parameter extra_io_rows_p = 1

    // the x/y cord of the 
    , parameter IO_x_cord_p = num_tiles_x_p -1 
    , parameter IO_y_cord_p = 0

    // parameters for victim cache    
    , parameter init_vcache_p = 0
    , parameter include_vcache_p = 1
    , parameter vcache_sets_p = 16 
    , parameter vcache_ways_p = 2 
    , parameter vcache_block_size_in_words_p = 8

    // parameter for AXI
    , parameter axi_id_width_p = 6
    , parameter axi_addr_width_p = 64
    , parameter axi_data_width_p = 256
    , parameter axi_burst_len_p = 1
    , localparam axi_strb_width_lp = (axi_data_width_p>>3)

    , localparam x_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_x_p)
    , localparam y_cord_width_lp = `BSG_SAFE_CLOG2(num_tiles_y_p + extra_io_rows_p)

    , localparam link_sif_width_lp =
      `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp,load_id_width_p)
    , localparam packet_width_lp =
      `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp,load_id_width_p)
  )
  (
    input clk_i
    , input reset_i

    , input  [num_tiles_x_p-1:0][link_sif_width_lp-1:0] ver_link_sif_i
    , output [num_tiles_x_p-1:0][link_sif_width_lp-1:0] ver_link_sif_o

    , input  [num_tiles_x_p-1:0][link_sif_width_lp-1:0] io_link_sif_i
    , output [num_tiles_x_p-1:0][link_sif_width_lp-1:0] io_link_sif_o

    , output finish_lo
    , output success_lo
    , output timeout_lo
  );

  initial begin
    $display("## creating manycore complex num_tiles (x,y) = %-d,%-d (%m)", num_tiles_x_p, num_tiles_y_p);
  end

  // cycle counter
  //
  wire [39:0] cycle_count;

  bsg_cycle_counter #(
    .width_p(40)
    ,.init_val_p(0)
  ) cc (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.ctr_r_o(cycle_count)
  );

  // link_sif struct.
  // we add this for easier debugging.
  //
  `declare_bsg_manycore_link_sif_s(addr_width_p,data_width_p,
    x_cord_width_lp,y_cord_width_lp,load_id_width_p);

  bsg_manycore_link_sif_s [num_tiles_x_p-1:0] io_link_sif_i_cast;
  bsg_manycore_link_sif_s [num_tiles_x_p-1:0] io_link_sif_o_cast;

  assign io_link_sif_i_cast = io_link_sif_i;
  assign io_link_sif_o = io_link_sif_o_cast;


  `declare_bsg_manycore_packet_s(addr_width_p,data_width_p,x_cord_width_lp,y_cord_width_lp,load_id_width_p);
  bsg_manycore_packet_s loader_data_lo;

  logic loader_v_lo;
  logic loader_ready_li;

  logic reset_r;
  always_ff @ (posedge clk_i) begin
    reset_r <= reset_i;
  end

  bsg_manycore_spmd_loader #(
    .icache_entries_num_p(icache_entries_num_p)
    ,.num_rows_p(num_tiles_y_p)
    ,.num_cols_p(num_tiles_x_p)
    ,.data_width_p(data_width_p)
    ,.addr_width_p(addr_width_p)
    ,.load_id_width_p(load_id_width_p)
    ,.epa_byte_addr_width_p(epa_byte_addr_width_p)
    ,.dram_ch_num_p(dram_ch_num_p)
    ,.dram_ch_addr_width_p(dram_ch_addr_width_p)
    ,.init_vcache_p(init_vcache_p)
    ,.vcache_entries_p(vcache_sets_p)
    ,.vcache_ways_p(vcache_ways_p)
    ,.x_cord_width_p(x_cord_width_lp)
    ,.y_cord_width_p(y_cord_width_lp)
  ) spmd_loader (
    .clk_i(clk_i)
    ,.reset_i(reset_r)
    ,.data_o(loader_data_lo)
    ,.v_o(loader_v_lo)
    ,.ready_i(loader_ready_li)
    ,.my_x_i(x_cord_width_lp'(IO_x_cord_p))
    ,.my_y_i(y_cord_width_lp'(IO_y_cord_p))
  );

  wire [num_tiles_x_p-1:0] finish_lo_vec;
  assign finish_lo = | finish_lo_vec;
   
  wire [num_tiles_x_p-1:0] success_lo_vec;
  assign success_lo = | success_lo_vec;
   
  wire [num_tiles_x_p-1:0] timeout_lo_vec;
  assign timeout_lo = | timeout_lo_vec;

  genvar i;

  //-----------------------------------------------------------------
  // Connects dram model
  if (include_vcache_p) begin: vcache
    
    initial begin
      $display("## Running simulation with vcache.");
    end

    logic [axi_id_width_p-1:0] awid;
    logic [axi_addr_width_p-1:0] awaddr;
    logic [7:0] awlen;
    logic [2:0] awsize;
    logic [1:0] awburst;
    logic [3:0] awcache;
    logic [2:0] awprot;
    logic awlock;
    logic awvalid;
    logic awready;

    logic [axi_data_width_p-1:0] wdata;
    logic [axi_strb_width_lp-1:0] wstrb;
    logic wlast;
    logic wvalid;
    logic wready;

    logic [axi_id_width_p-1:0] bid;
    logic [1:0] bresp;
    logic bvalid;
    logic bready;

    logic [axi_id_width_p-1:0] arid;
    logic [axi_addr_width_p-1:0] araddr;
    logic [7:0] arlen;
    logic [2:0] arsize;
    logic [1:0] arburst;
    logic [3:0] arcache;
    logic [2:0] arprot;
    logic arlock;
    logic arvalid;
    logic arready;

    logic [axi_id_width_p-1:0] rid;
    logic [axi_data_width_p-1:0] rdata;
    logic [1:0] rresp;
    logic rlast;
    logic rvalid;
    logic rready;

    logic [num_tiles_x_p-1:0][x_cord_width_lp-1:0] cache_x;
    logic [num_tiles_x_p-1:0][y_cord_width_lp-1:0] cache_y;

    for (i = 0; i < num_tiles_x_p; i++) begin
      assign cache_x[i] = x_cord_width_lp'(i);
      assign cache_y[i] = y_cord_width_lp'(num_tiles_y_p);
    end

    bsg_cache_wrapper_axi #(
      .num_cache_p(num_tiles_x_p)
      ,.data_width_p(data_width_p)
      ,.addr_width_p(addr_width_p)
      ,.block_size_in_words_p(vcache_block_size_in_words_p)
      ,.sets_p(vcache_sets_p)
      ,.ways_p(vcache_ways_p)

      ,.axi_id_width_p(axi_id_width_p)
      ,.axi_addr_width_p(axi_addr_width_p)
      ,.axi_data_width_p(axi_data_width_p)
      ,.axi_burst_len_p(axi_burst_len_p)

      ,.x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.load_id_width_p(load_id_width_p)
    ) vcache_axi (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.my_x_i(cache_x)
      ,.my_y_i(cache_y)

      ,.link_sif_i(ver_link_sif_i)
      ,.link_sif_o(ver_link_sif_o)

      ,.axi_awid_o(awid)
      ,.axi_awaddr_o(awaddr)
      ,.axi_awlen_o(awlen)
      ,.axi_awsize_o(awsize)
      ,.axi_awburst_o(awburst)
      ,.axi_awcache_o(awcache)
      ,.axi_awprot_o(awprot)
      ,.axi_awlock_o(awlock)
      ,.axi_awvalid_o(awvalid)
      ,.axi_awready_i(awready)

      ,.axi_wdata_o(wdata)
      ,.axi_wstrb_o(wstrb)
      ,.axi_wlast_o(wlast)
      ,.axi_wvalid_o(wvalid)
      ,.axi_wready_i(wready)

      ,.axi_bid_i(bid)
      ,.axi_bresp_i(bresp)
      ,.axi_bvalid_i(bvalid)
      ,.axi_bready_o(bready)

      ,.axi_arid_o(arid)
      ,.axi_araddr_o(araddr)
      ,.axi_arlen_o(arlen)
      ,.axi_arsize_o(arsize)
      ,.axi_arburst_o(arburst)
      ,.axi_arcache_o(arcache)
      ,.axi_arprot_o(arprot)
      ,.axi_arlock_o(arlock)
      ,.axi_arvalid_o(arvalid)
      ,.axi_arready_i(arready)

      ,.axi_rid_i(rid)
      ,.axi_rdata_i(rdata)
      ,.axi_rresp_i(rresp)
      ,.axi_rlast_i(rlast)
      ,.axi_rvalid_i(rvalid)
      ,.axi_rready_o(rready)
    );

    bsg_manycore_axi_mem #(
      .axi_id_width_p(axi_id_width_p)
      ,.axi_addr_width_p(axi_addr_width_p)
      ,.axi_data_width_p(axi_data_width_p)
      ,.axi_burst_len_p(axi_burst_len_p)
      ,.mem_els_p(2**26) // 2GB
    ) axi_mem (
      .clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.axi_awid_i(awid)
      ,.axi_awaddr_i(awaddr)
      ,.axi_awvalid_i(awvalid)
      ,.axi_awready_o(awready)

      ,.axi_wdata_i(wdata)
      ,.axi_wstrb_i(wstrb)
      ,.axi_wlast_i(wlast)
      ,.axi_wvalid_i(wvalid)
      ,.axi_wready_o(wready)

      ,.axi_bid_o(bid)
      ,.axi_bresp_o(bresp)
      ,.axi_bvalid_o(bvalid)
      ,.axi_bready_i(bready)

      ,.axi_arid_i(arid)
      ,.axi_araddr_i(araddr)
      ,.axi_arvalid_i(arvalid)
      ,.axi_arready_o(arready)

      ,.axi_rid_o(rid)
      ,.axi_rdata_o(rdata)
      ,.axi_rresp_o(rresp)
      ,.axi_rlast_o(rlast)
      ,.axi_rvalid_o(rvalid)
      ,.axi_rready_i(rready)
    );
    
  end
  else begin: ram

    initial begin
      $display("## Running simulation with block RAM.");
    end

    for (i = 0; i < num_tiles_x_p; i++) begin
      bsg_manycore_ram_model #(
        .x_cord_width_p(x_cord_width_lp)
        ,.y_cord_width_p(y_cord_width_lp)
        ,.data_width_p(data_width_p)
        ,.addr_width_p(addr_width_p)
        ,.load_id_width_p(load_id_width_p)
        ,.els_p(2**dram_ch_addr_width_p)
      ) ram (
        .clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.link_sif_i(ver_link_sif_i[i])
        ,.link_sif_o(ver_link_sif_o[i])

        ,.my_x_i(x_cord_width_lp'(i))
        ,.my_y_i(y_cord_width_lp'(num_tiles_y_p))
      );
    end
  end


  // we only set such a high number because we
  // know these packets can always be consumed
  // at the recipient and do not require any
  // forwarded traffic. for an accelerator
  // this would not be the case, and this
  // number must be set to the same as the
  // number of elements in the accelerator's
  // input fifo

  localparam spmd_max_out_credits_lp = 128;

  for (i = 0; i < num_tiles_x_p; i++) begin

    wire pass_thru_ready_lo;

    localparam credits_lp = (i== IO_x_cord_p) ? spmd_max_out_credits_lp : 4;

    wire [`BSG_SAFE_CLOG2(credits_lp+1)-1:0] creds;

    logic [x_cord_width_lp-1:0] pass_thru_x_li;
    logic [y_cord_width_lp-1:0] pass_thru_y_li;

    assign pass_thru_x_li = x_cord_width_lp ' (i);
    assign pass_thru_y_li = y_cord_width_lp ' (IO_y_cord_p);

    // hook up the ready signal if this is the SPMD loader
    // we handle credits here but could do it in the SPMD module too

    if (i == IO_x_cord_p) begin
      assign loader_ready_li = pass_thru_ready_lo & (|creds);

	    if (0) begin
        always_ff @ (negedge clk_i) begin
          if (~reset_i & loader_ready_li & loader_v_lo) begin
            $write("Loader: Transmitted addr=%-d'h%h (x_cord_width_lp=%-d)(y_cord_width_lp=%-d) "
              ,addr_width_p, mem_addr, x_cord_width_lp, y_cord_width_lp);
            `write_bsg_manycore_packet_s(loader_data_lo);
            $write("\n");
          end
        end
      end
    end

    bsg_nonsynth_manycore_monitor #(
      .x_cord_width_p(x_cord_width_lp)
      ,.y_cord_width_p(y_cord_width_lp)
      ,.addr_width_p(addr_width_p)
      ,.data_width_p(data_width_p)
      ,.load_id_width_p(load_id_width_p)
      ,.channel_num_p(i)
      ,.max_cycles_p(max_cycles_p)
      ,.pass_thru_p(i== IO_x_cord_p)
      // for the SPMD loader we don't anticipate
      // any backwards flow control; but for an
      // accelerator, we must be much more careful about
      // setting this
      ,.pass_thru_max_out_credits_p(credits_lp)
    ) bmm (
      .clk_i(clk_i)
      ,.reset_i(reset_r)
      ,.link_sif_i(io_link_sif_i_cast[i])
      ,.link_sif_o(io_link_sif_o_cast[i])
      ,.pass_thru_data_i(loader_data_lo )
      ,.pass_thru_v_i(loader_v_lo & loader_ready_li)
      ,.pass_thru_ready_o(pass_thru_ready_lo)
      ,.pass_thru_out_credits_o(creds)
      ,.pass_thru_x_i(pass_thru_x_li)
      ,.pass_thru_y_i(pass_thru_y_li)
      ,.cycle_count_i(cycle_count)
      ,.finish_o(finish_lo_vec[i])
      ,.success_o(success_lo_vec[i])
      ,.timeout_o(timeout_lo_vec[i])
    );
  end

endmodule
