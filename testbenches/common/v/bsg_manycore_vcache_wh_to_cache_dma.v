/**
 *    bsg_manycore_vcache_wh_to_cache_dma.v
 *    
 *    this converts vcache wh link to an array of cache dma interface to that it can be interfaced to
 *    bsg_cache_to_test_dram.v
 *
 *    Intended to be used for simulation only.
 */


`include "bsg_noc_links.vh"


module bsg_manycore_vcache_wh_to_cache_dma
  import bsg_cache_pkg::*;
  import bsg_manycore_pkg::*;
  #(parameter wh_flit_width_p="inv"
    , parameter wh_cid_width_p="inv"
    , parameter wh_len_width_p="inv"
    , parameter wh_cord_width_p="inv"
    , parameter wh_ruche_factor_p="inv"

    , parameter num_vcaches_p="inv"
    , parameter vcache_addr_width_p="inv"
    , parameter vcache_data_width_p="inv"
    , parameter vcache_dma_data_width_p="inv"
    , parameter vcache_block_size_in_words_p="inv"

    
    , parameter num_pods_x_p ="inv"
    , parameter pod_start_x_p = 0
    , parameter num_tiles_x_p = "inv"
    , parameter lg_num_tiles_x_lp=`BSG_SAFE_CLOG2(num_tiles_x_p)
    , parameter lg_num_pods_x_lp = `BSG_SAFE_CLOG2(num_pods_x_p)

    // FIFO parameters
    , parameter in_fifo_els_p = 8

    , parameter lg_num_vcaches_lp=`BSG_SAFE_CLOG2(num_vcaches_p)
    , parameter data_len_lp=(vcache_data_width_p*vcache_block_size_in_words_p/vcache_dma_data_width_p)
    , parameter count_width_lp = `BSG_SAFE_CLOG2(data_len_lp)

    , parameter wh_link_sif_width_lp=`bsg_ready_and_link_sif_width(wh_flit_width_p)
    , parameter dma_pkt_width_lp=`bsg_cache_dma_pkt_width(vcache_addr_width_p)


  )
  (
    input clk_i
    , input reset_i


    // wormhole link
    , input  [wh_link_sif_width_lp-1:0] wh_link_sif_i
    , output [wh_link_sif_width_lp-1:0] wh_link_sif_o
   

    // cache DMA 
    , output logic [num_vcaches_p-1:0][dma_pkt_width_lp-1:0] dma_pkt_o
    , output logic [num_vcaches_p-1:0] dma_pkt_v_o
    , input [num_vcaches_p-1:0] dma_pkt_yumi_i

    , input [num_vcaches_p-1:0][vcache_dma_data_width_p-1:0] dma_data_i
    , input [num_vcaches_p-1:0] dma_data_v_i
    , output logic [num_vcaches_p-1:0] dma_data_ready_o

    , output logic [num_vcaches_p-1:0][vcache_dma_data_width_p-1:0] dma_data_o
    , output logic [num_vcaches_p-1:0] dma_data_v_o
    , input [num_vcaches_p-1:0] dma_data_yumi_i
  );


  // structs
  `declare_bsg_ready_and_link_sif_s(wh_flit_width_p,wh_link_sif_s);
  `declare_bsg_cache_dma_pkt_s(vcache_addr_width_p);
  `declare_bsg_manycore_vcache_wh_header_flit_s(wh_flit_width_p,wh_cord_width_p,wh_len_width_p,wh_cid_width_p);


  // cast wormhole links
  wh_link_sif_s wh_link_sif_in;
  wh_link_sif_s wh_link_sif_out;
  assign wh_link_sif_in = wh_link_sif_i;
  assign wh_link_sif_o = wh_link_sif_out;


  // Buffer incoming flits.
  logic [wh_flit_width_p-1:0] in_fifo_data_lo;
  logic in_fifo_yumi_li;
  logic in_fifo_v_lo;

  bsg_fifo_1r1w_small #(
    .els_p(in_fifo_els_p)
    ,.width_p(wh_flit_width_p)
  ) in_fifo (
    .clk_i    (clk_i)
    ,.reset_i (reset_i)

    ,.v_i     (wh_link_sif_in.v)
    ,.data_i  (wh_link_sif_in.data)
    ,.ready_o (wh_link_sif_out.ready_and_rev)

    ,.v_o     (in_fifo_v_lo)
    ,.data_o  (in_fifo_data_lo)
    ,.yumi_i  (in_fifo_yumi_li)
  );


  // DMA pkt going out
  bsg_cache_dma_pkt_s dma_pkt_out;
  for (genvar i = 0; i < num_vcaches_p; i++) begin
    assign dma_pkt_o[i] = dma_pkt_out;
  end


  // header flits coming in and going out
  bsg_manycore_vcache_wh_header_flit_s header_flit_in, header_flit_out;
  assign header_flit_in = in_fifo_data_lo;


  // cid, src_cord table
  logic [num_vcaches_p-1:0][wh_cid_width_p-1:0] cid_r;
  logic [num_vcaches_p-1:0][wh_cord_width_p-1:0] src_cord_r;
  logic [wh_cid_width_p-1:0] cid_n;
  logic [wh_cord_width_p-1:0] src_cord_n;
  logic [lg_num_vcaches_lp-1:0] table_w_addr;
  logic table_we;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      cid_r <= '0;
      src_cord_r <= '0;
    end
    else begin
      if (table_we) begin
        cid_r[table_w_addr] <= cid_n;
        src_cord_r[table_w_addr] <= src_cord_n;
      end
    end
  end



  // send FSM
  // receives wh packets and cache dma pkts.
  typedef enum logic [1:0] {
    SEND_RESET,
    SEND_READY,
    SEND_DMA_PKT,
    SEND_EVICT_DATA
  } send_state_e;

  send_state_e send_state_r, send_state_n;
  logic write_not_read_r, write_not_read_n;
  logic [lg_num_vcaches_lp-1:0] send_cache_id_r, send_cache_id_n;

  logic send_clear_li;
  logic send_up_li;
  logic [count_width_lp-1:0] send_count_lo;
  bsg_counter_clear_up #(
    .max_val_p(data_len_lp-1)    
    ,.init_val_p(0)
  ) send_count (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.clear_i(send_clear_li)
    ,.up_i(send_up_li)
    ,.count_o(send_count_lo)
  );

  wire [lg_num_vcaches_lp-1:0] send_cache_id;
  if (num_pods_x_p == 1) begin
    // For pod 1x1, there are 1 HBM on each side of west and east.
    // Left half of top and bottom vcaches (16 total) maps to ch0 of HBM2 on west.
    // Right half of top and bottom vcaches (16 total) maps to ch0 of HBM2 on east.
    assign send_cache_id = {
      (1)'(header_flit_in.cid/wh_ruche_factor_p),
      header_flit_in.src_cord[lg_num_tiles_x_lp-2:0]
    };
  end
  else begin
    //  The left half of the pod array maps to HBM2 on the left side, and the right half on the right. 
    //  HBM2 channels are allocated to pods starting from the top left corner.
    //  Within a pod, a row of vcaches (16) is allocated to a channel, so that there is one-to-one mapping from
    //  vcache to HBM2 bank.  
    //  
    //    
    // For pod 4x4
    //
    // [dev0-ch0] [dev0-ch2] [dev2-ch0] [dev2-ch2] 
    // [  m  c  ] [   mc   ] [  m  c  ] [   mc   ]
    // [dev0-ch1] [dev0-ch3] [dev2-ch1] [dev2-ch3]
    //
    // [dev0-ch4] [dev0-ch6] [dev2-ch4] [dev2-ch6]
    // [  m  c  ] [   mc   ] [  m  c  ] [   mc   ]
    // [dev0-ch5] [dev0-ch7] [dev2-ch5] [dev2-ch7]
    //
    // [dev1-ch0] [dev1-ch2] [dev3-ch0] [dev3-ch2]
    // [  m  c  ] [   mc   ] [  m  c  ] [   mc   ]
    // [dev1-ch1] [dev0-ch3] [dev3-ch1] [dev3-ch3]
    //
    // [dev1-ch4] [dev1-ch6] [dev3-ch4] [dev3-ch6]
    // [  m  c  ] [   mc   ] [  m  c  ] [   mc   ]
    // [dev1-ch5] [dev1-ch7] [dev3-ch5] [dev3-ch7]
    //
    assign send_cache_id = {
      (lg_num_pods_x_lp-1)'((header_flit_in.src_cord[wh_cord_width_p-1:lg_num_tiles_x_lp] - pod_start_x_p)%(num_pods_x_p/2)),
      (1)'(header_flit_in.cid/wh_ruche_factor_p),
      header_flit_in.src_cord[lg_num_tiles_x_lp-1:0]
    };
  end
  
  

  always_comb begin
    send_state_n = send_state_r;
    write_not_read_n = write_not_read_r;
    send_cache_id_n = send_cache_id_r;
    table_we = 1'b0;
    table_w_addr = '0;
    src_cord_n = '0;
    cid_n = '0;   
  
    in_fifo_yumi_li = 1'b0;
    
    send_clear_li = 1'b0;
    send_up_li = 1'b0;
    dma_pkt_v_o = '0;
    dma_pkt_out = '0;

    dma_data_v_o = '0;
    dma_data_o = '0;

    case (send_state_r)
      // coming out of reset
      SEND_RESET: begin
        send_state_n = SEND_READY;
      end
    
      // wait for a header flit.
      // store the write_not_read, src_cord.
      // save the cid in a table.
      SEND_READY: begin
        if (in_fifo_v_lo) begin
          in_fifo_yumi_li = 1'b1;
          write_not_read_n = header_flit_in.write_not_read;
          src_cord_n = header_flit_in.src_cord;
          cid_n = header_flit_in.cid;
          table_w_addr = send_cache_id;
          table_we = 1'b1;
          send_cache_id_n = send_cache_id;
          send_state_n = SEND_DMA_PKT;
        end
      end

      // take the addr flit and send out the dma pkt.
      // For read, return to SEND_READY.
      // For write, move to SEND_EVICT_DATA to pass the evict data.
      SEND_DMA_PKT: begin
        dma_pkt_v_o[send_cache_id_r] = in_fifo_v_lo;
        dma_pkt_out.write_not_read = write_not_read_r;
        dma_pkt_out.addr = vcache_addr_width_p'(in_fifo_data_lo);
      
        in_fifo_yumi_li = dma_pkt_yumi_i[send_cache_id_r];
        send_state_n = dma_pkt_yumi_i[send_cache_id_r]
          ? (write_not_read_r ? SEND_EVICT_DATA : SEND_READY)
          : SEND_DMA_PKT;
      end

      // once all evict data has been passed along return to SEND_READY
      SEND_EVICT_DATA: begin
        dma_data_v_o[send_cache_id_r] = in_fifo_v_lo;
        dma_data_o[send_cache_id_r] = in_fifo_data_lo;
        if (dma_data_yumi_i[send_cache_id_r]) begin
          in_fifo_yumi_li = 1'b1;
          send_up_li = send_count_lo != data_len_lp-1;
          send_clear_li = send_count_lo == data_len_lp-1;
          send_state_n = (send_count_lo == data_len_lp-1)
            ? SEND_READY
            : SEND_EVICT_DATA;
        end
      end

    endcase    

  end



  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      send_state_r <= SEND_RESET;
      write_not_read_r <= 1'b0;
      send_cache_id_r <= '0;
    end
    else begin
      send_state_r <= send_state_n;
      write_not_read_r <= write_not_read_n;
      send_cache_id_r <= send_cache_id_n;
    end
  end



  // receiver FSM
  // receives dma_data_i and send them to the vcaches using wh link.
  typedef enum logic [1:0] {
    RECV_RESET,
    RECV_READY,
    RECV_HEADER,
    RECV_FILL_DATA
  } recv_state_e;

  recv_state_e recv_state_r, recv_state_n;
  logic [lg_num_vcaches_lp-1:0] recv_cache_id_r, recv_cache_id_n;


  logic rr_v_lo;
  logic rr_yumi_li;
  logic [lg_num_vcaches_lp-1:0] rr_addr_lo;
  logic [num_vcaches_p-1:0] rr_grants_lo;
  bsg_arb_round_robin #(
    .width_p(num_vcaches_p)
  ) rr0 (
    .clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.reqs_i(dma_data_v_i)
    ,.grants_o(rr_grants_lo)
    ,.yumi_i(rr_yumi_li)
  );
  assign rr_v_lo = |dma_data_v_i;
  bsg_encode_one_hot #(
    .width_p(num_vcaches_p)
  ) eoh (
    .i(rr_grants_lo)
    ,.addr_o(rr_addr_lo)
    ,.v_o()
  );


  logic recv_clear_li;
  logic recv_up_li;
  logic [count_width_lp-1:0] recv_count_lo;
  bsg_counter_clear_up #(
    .max_val_p(data_len_lp-1)    
    ,.init_val_p(0)
  ) recv_count (
    .clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.clear_i(recv_clear_li)
    ,.up_i(recv_up_li)
    ,.count_o(recv_count_lo)
  );




  always_comb begin

    wh_link_sif_out.v = 1'b0;
    wh_link_sif_out.data = '0;

    rr_yumi_li = 1'b0;

    recv_state_n = recv_state_r;
    recv_cache_id_n = recv_cache_id_r;

    recv_clear_li = 1'b0;
    recv_up_li = 1'b0;

    header_flit_out.unused = '0;
    header_flit_out.write_not_read = 1'b0; // dont matter
    header_flit_out.src_cord = '0; // dont matter
    header_flit_out.cid = cid_r[recv_cache_id_r];
    header_flit_out.len = data_len_lp;
    header_flit_out.dest_cord = src_cord_r[recv_cache_id_r];

    dma_data_ready_o = '0;

    case (recv_state_r)

      // coming out of reset
      RECV_RESET: begin
        recv_state_n = RECV_READY;
      end

      // wait for one of dma_data_v_i to be 1.
      // save the cache id.
      RECV_READY: begin
        if (rr_v_lo) begin
          rr_yumi_li = 1'b1;
          recv_cache_id_n = rr_addr_lo;
          recv_state_n = RECV_HEADER;
        end
      end     
     
      // send out header to dest vcache
      RECV_HEADER: begin
        wh_link_sif_out.v = 1'b1;
        wh_link_sif_out.data = header_flit_out;
        if (wh_link_sif_in.ready_and_rev) begin
          recv_state_n = RECV_FILL_DATA;
        end
      end
 
      // send the data flits to the vcache.
      // once it's done, go back to RECV_READY.
      RECV_FILL_DATA: begin
        wh_link_sif_out.v = dma_data_v_i[recv_cache_id_r];
        wh_link_sif_out.data = dma_data_i[recv_cache_id_r];
        dma_data_ready_o[recv_cache_id_r] = wh_link_sif_in.ready_and_rev;
        if (dma_data_v_i[recv_cache_id_r] & wh_link_sif_in.ready_and_rev) begin
          recv_clear_li = (recv_count_lo == data_len_lp-1);
          recv_up_li = (recv_count_lo != data_len_lp-1);
          recv_state_n = (recv_count_lo == data_len_lp-1)
            ? RECV_READY
            : RECV_FILL_DATA;
        end
      end

    endcase
  end


  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      recv_state_r <= RECV_RESET;
      recv_cache_id_r <= '0;
    end
    else begin
      recv_state_r <= recv_state_n;
      recv_cache_id_r <= recv_cache_id_n;
    end
  end


endmodule
