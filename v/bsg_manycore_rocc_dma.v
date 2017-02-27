//====================================================================
// bsg_manycore_rocc_dma.v
// 02/21/2016, shawnless.xie@gmail.com
//====================================================================
// This module implements the DMA function for movind data from Rocket
// to the manycore memory
// 1. ONLY supports word transfer yet.
// 2. Address must be aligned with 4 bytes.
// 3. The bit width of the manycore related registers are rocc_addr_width
//    because the information of x_tiles, y_tiles are included in manycore
//    address, the related registers should be 64 bits. So does the adder.
// 4. The bit width of the rocket   related registers are rocc_mem_addr_width
//
// 5. The bit width of following registers is determined by cfg_width_p
//    run_bytes register
//    repeats   register
//
`include "bsg_rocc.v"

module bsg_manycore_rocc_dma #(
        addr_width_p = "inv"  //the data width for manycore data
       ,data_width_p = "inv"  //the addr width for manycore address
       ,cfg_width_p  =  16    //the configuration register width
    )(
       input        clk_i
      ,input        reset_i
      //command signals
      ,input                            core_cmd_valid_i
      ,input  rocc_core_cmd_s           core_cmd_s_i
      ,output                           core_cmd_ready_o

      ,output                           core_resp_valid_o
      ,output rocc_core_resp_s          core_resp_s_o
      ,input                            core_resp_ready_i
      //rocket mem signals
      ,output                           mem_req_valid_o
      ,output  rocc_mem_req_s           mem_req_s_o
      ,input                            mem_req_ready_i

      ,input                            mem_resp_valid_i
      ,input  rocc_mem_resp_s           mem_resp_s_i
      //manycore mem signals
      ,output                           rocc2manycore_v_o
      ,output rocc_manycore_addr_s      rocc2manycore_addr_s_o
      ,output [data_width_p-1:0]        rocc2manycore_data_o
      ,input                            rocc2manycore_ready_i

      //DMA status signals
      ,input                            mem_req_credit_i
    );

  localparam zero_ext_lp = (rocc_data_width_gp - 2*cfg_width_p);
/////////////////////////////////////////////////////////////////////////
// manycore address registers.
   logic [rocc_addr_width_gp-1 : 0   ]         manycore_byte_addr_r;
   //save the address that will send to the manycore
   logic [rocc_addr_width_gp-1 : 0   ]         manycore_byte_addr_r_r;

   wire manycore_addr_cfg_en    = core_cmd_valid_i
                              & ( core_cmd_s_i.instr.funct7 == eRoCC_core_dma_addr);

   wire [rocc_addr_width_gp-1 : 0] manycore_addr_cfg_value =
                                  core_cmd_s_i.rs1_val[ rocc_addr_width_gp-1:0 ] ;

   wire manycore_addr_update_en;
   wire [rocc_addr_width_gp-1 : 0] manycore_addr_update_value;

   always_ff@(posedge clk_i) begin
   if( reset_i)                     manycore_byte_addr_r <= 'b0;
   else if( manycore_addr_cfg_en)   manycore_byte_addr_r <= manycore_addr_cfg_value;
   else if( manycore_addr_update_en)manycore_byte_addr_r <= manycore_addr_update_value;
   end

   always_ff@(posedge clk_i) begin
        if( manycore_addr_update_en) manycore_byte_addr_r_r <= manycore_byte_addr_r ;
   end

/////////////////////////////////////////////////////////////////////////
// rocket address registers.
   logic [rocc_mem_addr_width_gp-1:0 ]         rocket_byte_addr_r;
   wire rocket_addr_cfg_en    = core_cmd_valid_i
                              & ( core_cmd_s_i.instr.funct7 == eRoCC_core_dma_addr);

   wire [rocc_mem_addr_width_gp-1 : 0] rocket_addr_cfg_value =
                                  core_cmd_s_i.rs2_val[ rocc_mem_addr_width_gp-1:0 ];

   wire rocket_addr_update_en;
   wire [rocc_mem_addr_width_gp-1 : 0] rocket_addr_update_value;

   always_ff@(posedge clk_i) begin
   if( reset_i)                     rocket_byte_addr_r <= 'b0;
   else if( rocket_addr_cfg_en)     rocket_byte_addr_r <= rocket_addr_cfg_value;
   else if( rocket_addr_update_en)  rocket_byte_addr_r <= rocket_addr_update_value;
   end

/////////////////////////////////////////////////////////////////////////
// manycore skip registers.
   logic [rocc_addr_width_gp-1 : 0]         manycore_byte_skip_r;

   wire manycore_skip_cfg_en    = core_cmd_valid_i
                              & ( core_cmd_s_i.instr.funct7 == eRoCC_core_dma_skip);

   wire [rocc_addr_width_gp-1 : 0] manycore_skip_cfg_value =
                                  core_cmd_s_i.rs1_val[ rocc_addr_width_gp-1:0 ];

   always_ff@(posedge clk_i) begin
   if( reset_i)                     manycore_byte_skip_r <= 'b0;
   else if( manycore_skip_cfg_en)   manycore_byte_skip_r <= manycore_skip_cfg_value;
   end

/////////////////////////////////////////////////////////////////////////
// rocket skip registers.
   logic [rocc_mem_addr_width_gp-1:0 ]         rocket_byte_skip_r;
   wire rocket_skip_cfg_en    = core_cmd_valid_i
                              & ( core_cmd_s_i.instr.funct7 == eRoCC_core_dma_skip);

   wire [rocc_mem_addr_width_gp-1 : 0] rocket_skip_cfg_value =
                                  core_cmd_s_i.rs2_val[rocc_mem_addr_width_gp-1:0];


   always_ff@(posedge clk_i) begin
   if( reset_i)                     rocket_byte_skip_r <= 'b0;
   else if( rocket_skip_cfg_en)     rocket_byte_skip_r <= rocket_skip_cfg_value;
   end

/////////////////////////////////////////////////////////////////////////
// run_bytes register
   logic [cfg_width_p -1:0 ]         run_bytes_r;
   wire run_bytes_cfg_en    = core_cmd_valid_i
                              & ( core_cmd_s_i.instr.funct7 == eRoCC_core_dma_xfer);

   wire [cfg_width_p-1 : 0] run_bytes_cfg_value =
                                  core_cmd_s_i.rs1_val[cfg_width_p-1:0] ;


   always_ff@(posedge clk_i) begin
   if( reset_i)                   run_bytes_r  <= 'b0;
   else if( run_bytes_cfg_en)     run_bytes_r  <= run_bytes_cfg_value;
   end
/////////////////////////////////////////////////////////////////////////
// repeats register
   logic [cfg_width_p-1:0 ]         repeats_r;
   wire repeats_cfg_en    = core_cmd_valid_i
                        & ( core_cmd_s_i.instr.funct7 == eRoCC_core_dma_xfer);

   wire [cfg_width_p-1 : 0] repeats_cfg_value =
                                  core_cmd_s_i.rs2_val[ cfg_width_p-1:0 ];


   always_ff@(posedge clk_i) begin
   if( reset_i)                 repeats_r  <= 'b0;
   else if( repeats_cfg_en)     repeats_r  <= repeats_cfg_value;
   end
/////////////////////////////////////////////////////////////////////////
// The state machine & related counters

// this is the signal which control the pulse of DMA
   wire rocket_mem_req_valid;
   wire dma_repeats_finish;

   eRoCC_dma_stat  curr_stat_e_r,  next_stat_e ;

   always_ff@(posedge clk_i)  begin
        if( reset_i ) curr_stat_e_r <= eRoCC_dma_idle;
        else          curr_stat_e_r <= next_stat_e   ;
   end

   wire dma_run_en = core_cmd_valid_i & (core_cmd_s_i.instr.funct7 == eRoCC_core_dma_xfer );
   always_comb begin
    case ( curr_stat_e_r )
        eRoCC_dma_idle :
            if( dma_run_en)         next_stat_e = eRoCC_dma_busy;
            else                    next_stat_e = eRoCC_dma_idle;
        eRoCC_dma_busy :
            if( dma_repeats_finish) next_stat_e = eRoCC_dma_idle;
            else                    next_stat_e = eRoCC_dma_busy;
    endcase
   end

//the run_bytes counter
  wire run_word_overflowed;
  bsg_counter_en_overflow #( .width_p ( cfg_width_p-2 ) ) run_word_counter (
        .clk_i      ( clk_i                                     )
       ,.reset_i    ( reset_i   | run_bytes_cfg_en              )
       ,.en_i       ( rocket_mem_req_valid                      )
       ,.limit_i    ( run_bytes_r[cfg_width_p-1:2]              )
       ,.counter_o  (                                           )
       ,.overflowed_o( run_word_overflowed                      )
    );

//the repeats counter
  wire repeats_overflowed;
  bsg_counter_en_overflow #( .width_p ( cfg_width_p) ) repeats_counter (
        .clk_i      ( clk_i                                     )
       ,.reset_i    ( reset_i  | repeats_cfg_en                 )
       ,.en_i       ( run_word_overflowed & rocket_mem_req_valid)
       ,.limit_i    ( repeats_r                                 )
       ,.counter_o  (                                           )
       ,.overflowed_o( repeats_overflowed                       )
    );

  assign dma_repeats_finish = run_word_overflowed & repeats_overflowed;
//the manycore address update
  assign manycore_addr_update_en    = rocket_mem_req_valid ;
  assign manycore_addr_update_value = run_word_overflowed
                                    ? (manycore_byte_addr_r + manycore_byte_skip_r+4)
                                    : (manycore_byte_addr_r + 4                     )  ;

//the rocket address update
  assign rocket_addr_update_en    = rocket_mem_req_valid ;
  assign rocket_addr_update_value = run_word_overflowed
                                    ? (rocket_byte_addr_r + rocket_byte_skip_r + 4 )
                                    : (rocket_byte_addr_r + 4                      )   ;

/////////////////////////////////////////////////////////////////////////
// The signals to the rocket memory

   //TODO: We issue request only if it is able to receive the result. We check
   //the rocc2manycore_ready_i to see if we are able to receive the result.
   //this should work under current design because there won't be more RoCC
   //commands writing manycore memory while there is a dma on goning,
   //but this is not strictly correct.

   //TODO: We issue request only if there is no pending request in rocket
   //memory. We can improve this by using FIFO which can outputs the number of
   //current empty slots, and counts the pending request
   assign rocket_mem_req_valid  = ( curr_stat_e_r  == eRoCC_dma_busy )
                                &   mem_req_ready_i
                                &   mem_req_credit_i
                                &   rocc2manycore_ready_i ;

   //assgin the output signals.
   assign mem_req_valid_o       = rocket_mem_req_valid                      ;
   assign mem_req_s_o           = get_rocket_load_req( rocket_byte_addr_r ) ;

/////////////////////////////////////////////////////////////////////////
// The signals to the manycore memory
   assign rocc2manycore_v_o         = mem_resp_valid_i
                                  & ( mem_resp_s_i.resp_cmd == eRoCC_mem_load);

   assign rocc2manycore_data_o      = mem_resp_s_i.resp_data[ data_width_p-1:0];
   assign rocc2manycore_addr_s_o    = manycore_byte_addr_r_r                   ;

//functions to encode the rocket memory request
  function rocc_mem_req_s get_rocket_load_req(
            input [rocc_mem_addr_width_gp-1:0 ] addr);
           get_rocket_load_req = '{ req_addr :  addr                     ,
                                    req_tag  :  rocc_mem_tag_width_gp'(0),
                                    req_cmd  :  eRoCC_mem_load           ,
                                    //currently only support 32bits
                                    req_typ  :  eRoCC_mem_32bits         ,
                                    req_phys :  1'b1                     ,
                                    req_data :  rocc_data_width_gp'(0)
                                   };

  endfunction
/////////////////////////////////////////////////////////////////////////
/*
  logic [2*cfg_width_p-1:0] bytes_transferred_r;
  always_ff@(posedge clk_i) begin
    if( reset_i )                   bytes_transferred_r <= '0;
    else if( rocket_mem_req_valid ) bytes_transferred_r <= bytes_transferred_r + 4;
  end

  logic core_fence_req_r;
  wire  core_fence_req = core_cmd_valid_i &( core_cmd_s_i.instr.funct7 == eRoCC_core_dma_fence);
  always_ff@(posedge clk_i) begin
    if( reset_i )               core_fence_req_r <= 1'b0;
    else if(core_fence_req)     core_fence_req_r <= 1'b1;
    else if(core_resp_valid_o)  core_fence_req_r <= 1'b0;
  end
  assign core_resp_valid_o        = core_fence_req_r & core_cmd_ready_o;

  assign core_resp_s_o            = { {zero_ext_lp'(0)}, bytes_transferred_r};
*/
  assign core_resp_valid_o        = 1'b0;
  assign core_resp_s_o            =  'b0;
  assign core_cmd_ready_o         = (curr_stat_e_r != eRoCC_dma_busy);
endmodule
