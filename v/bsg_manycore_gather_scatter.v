//====================================================================
// bsg_manycore_gather_scatter.v
// 03/10/2019, shawnless.xie@gmail.com
//====================================================================
// A module that do gather/scatter  
//
`include "bsg_manycore_packet.vh"

module bsg_manycore_gather_scatter#( 
                             x_cord_width_p         = "inv"
                            ,y_cord_width_p         = "inv"
                            ,dmem_size_p            = "inv" 
                            ,data_width_p           = 32
                            ,addr_width_p           = 32
                            ,load_id_width_p        = 11
                            ,max_out_credits_p      = 200
                            ,packet_width_lp                = `bsg_manycore_packet_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p, load_id_width_p)
                            ,return_packet_width_lp         = `bsg_manycore_return_packet_width(x_cord_width_p,y_cord_width_p,data_width_p,load_id_width_p)
                            ,bsg_manycore_link_sif_width_lp = `bsg_manycore_link_sif_width(addr_width_p,data_width_p,x_cord_width_p,y_cord_width_p, load_id_width_p)
                            ,debug_p                = 1
                            /* Dummy parameter for compatability with socket*/    
                            ,hetero_type_p          = 1
                            ,epa_byte_addr_width_p  = "inv" 
                            ,dram_ch_addr_width_p   = "inv"
                            ,dram_ch_start_col_p    = "inv"
                            ,icache_entries_p       = "inv"
                            ,icache_tag_width_p     = "inv"
                            //Gather/Scatter parameters
                            ,mem_begin_word_addr_lp = dmem_size_p
                           )
   (  input clk_i
    , input reset_i

    // mesh network
    , input  [bsg_manycore_link_sif_width_lp-1:0] link_sif_i
    , output [bsg_manycore_link_sif_width_lp-1:0] link_sif_o

    , input   [x_cord_width_p-1:0]                my_x_i
    , input   [y_cord_width_p-1:0]                my_y_i

    // Dummy outputs to be compatilbe with the socket
    , output                                      freeze_o
    );

    //--------------------------------------------------------------
    //  CSR definitions
     enum {
         CSR_CMD_IDX =0         //command, write to start the transcation
        ,CSR_SRC_ADDR_HI_IDX    //Source Address Configuration High, using Norm_NPA_s format
        ,CSR_SRC_ADDR_LO_IDX    //Source Address Configuration Low,  using Norm_NPA_s format
        ,CSR_SRC_DIM_HI_IDX     //Source Dimension Configuration High, using Norm_NPA_s format
        ,CSR_SRC_DIM_LO_IDX     //Source Dimension Configuration Low,  using Norm_NPA_s format
        ,CSR_SRC_INCR_HI_IDX    //Source Increasement Configuration High, using Norm_NPA_s format
        ,CSR_SRC_INCR_LO_IDX    //Source Increasement Configuration Low,  using Norm_NPA_s format

        ,CSR_DST_ADDR_IDX       //Local Desitination  addr
        ,CSR_SIG_ADDR_HI_IDX    //Signal Addr High, using Norm_NPA_s format
        ,CSR_SIG_ADDR_LO_IDX    //Signal Addr Low, using Norm_NPA_s format
        ,CSR_NUM_lp
    } CSR_INDX;
    
    typedef struct packed {
        logic [7 : 0 ] reserved8 ;               //MSB
        logic [7 : 0 ] chip8     ;
        logic [7 : 0]  y8        ;
        logic [7 : 0]  x8        ;
        logic [31 : 0] epa32     ;               //LSB
    } Norm_NPA_s;

    typedef struct packed {
                logic [1 : 0] y_order;
                logic [1 : 0] x_order;
                logic [1 : 0] epa_order;
    }dma_cmd_order;

    //--------------------------------------------------------------
    // The CSR Memory
    logic [data_width_p-1:0] CSR_mem_r [ CSR_NUM_lp ]           ; 

    wire Norm_NPA_s src_addr_s = { CSR_mem_r[ CSR_SRC_ADDR_HI_IDX ],  CSR_mem_r[ CSR_SRC_ADDR_LO_IDX ]};
    wire Norm_NPA_s src_dim_s  = { CSR_mem_r[ CSR_SRC_DIM_HI_IDX  ],  CSR_mem_r[ CSR_SRC_DIM_LO_IDX  ]};
    wire Norm_NPA_s src_incr_s = { CSR_mem_r[ CSR_SRC_INCR_HI_IDX ],  CSR_mem_r[ CSR_SRC_INCR_LO_IDX ]};
    wire Norm_NPA_s sig_addr_s = { CSR_mem_r[ CSR_SIG_ADDR_HI_IDX ],  CSR_mem_r[ CSR_SIG_ADDR_LO_IDX ]};


    logic                               in_v_lo                 ;
    logic[data_width_p-1:0]             in_data_lo              ;
    logic[addr_width_p-1:0]             in_addr_lo              ;
    logic                               in_we_lo                ;
    logic[(data_width_p>>3)-1:0]        in_mask_lo              ;

    wire is_CSR_addr = in_addr_lo < CSR_NUM_lp                 ;
    wire dma_run_en  =  in_v_lo & ( in_addr_lo == CSR_CMD_IDX ) & in_we_lo;
    wire dma_cmd_order  cmd_order_s = dma_run_en ? in_data_lo[ $bits(dma_cmd_order)-1 : 0 ]
                                                 : CSR_mem_r[ CSR_CMD_IDX] [ $bits(dma_cmd_order)-1 : 0];
    // write
    always@( posedge clk_i)
        if( in_we_lo & in_v_lo  & is_CSR_addr )
                CSR_mem_r[ in_addr_lo ] <=  in_data_lo;

    // read
    logic                               CSR_returning_v_r           ;
    logic[data_width_p-1:0]             CSR_returning_data_r             ;
    always@( posedge clk_i)
        if( ~in_we_lo & in_v_lo & is_CSR_addr )
                CSR_returning_data_r <= CSR_mem_r[ in_addr_lo ] ;

    always_ff@(posedge clk_i)
        if( reset_i ) CSR_returning_v_r <= 1'b0;
        else          CSR_returning_v_r <= in_v_lo & is_CSR_addr ;
    //--------------------------------------------------------------
    // instantiate the endpoint standard

   `declare_bsg_manycore_packet_s(addr_width_p, data_width_p, x_cord_width_p, y_cord_width_p, load_id_width_p);
    bsg_manycore_packet_s             out_packet_li     ;
    logic                             out_v_li          ;
    logic                             out_ready_lo      ;

    logic                             in_yumi_li        ;
    logic                             returning_v_li    ;
    logic[data_width_p-1:0]           returning_data_li ;

    logic                             returned_v_lo     ;
    logic[data_width_p-1:0]           returned_data_lo  ;
    logic[load_id_width_p-1:0]        returned_load_id_r_lo, load_id_r;
    logic[$clog2(max_out_credits_p+1)-1:0] out_credits_lo;
    bsg_manycore_endpoint_standard  #(
                              .x_cord_width_p        ( x_cord_width_p    )
                             ,.y_cord_width_p        ( y_cord_width_p    )
                             ,.fifo_els_p            ( 4                 )
                             ,.data_width_p          ( data_width_p      )
                             ,.addr_width_p          ( addr_width_p      )
                             ,.load_id_width_p       ( load_id_width_p   )
                             ,.max_out_credits_p     ( max_out_credits_p )
                        )endpoint_gs

   ( .clk_i
    ,.reset_i

    // mesh network
    ,.link_sif_i
    ,.link_sif_o
    ,.my_x_i
    ,.my_y_i

    // local incoming data interface
    ,.in_v_o     ( in_v_lo              )
    ,.in_yumi_i  ( in_yumi_li           )
    ,.in_data_o  ( in_data_lo           )
    ,.in_mask_o  ( in_mask_lo           )
    ,.in_addr_o  ( in_addr_lo           )
    ,.in_we_o    ( in_we_lo             )
    ,.in_src_x_cord_o(  )
    ,.in_src_y_cord_o(  )

    // The memory read value
    ,.returning_data_i  ( returning_data_li )
    ,.returning_v_i     ( returning_v_li )

    // local outgoing data interface (does not include credits)
    // Tied up all the outgoing signals
    ,.out_v_i           ( out_v_li                      )
    ,.out_packet_i      ( out_packet_li                 )
    ,.out_ready_o       ( out_ready_lo                  )
   // local returned data interface
   // Like the memory interface, processor should always ready be to
   // handle the returned data
    ,.returned_data_r_o         (returned_data_lo     )
    ,.returned_v_r_o            (returned_v_lo        )
    ,.returned_load_id_r_o      (returned_load_id_r_lo)
    ,.returned_fifo_full_o      (             )
    ,.returned_yumi_i           (returned_v_lo)

    ,.out_credits_o     (out_credits_lo               )
    );


    //--------------------------------------------------------------
    //  The DMA state machine
    typedef enum logic[1:0] {
        eGS_dma_idle    = 2'd0
       ,eGS_dma_busy    = 2'd1
       ,eGS_dma_wait    = 2'd2
       ,eGS_dma_signal  = 2'd3
    }GS_dma_stat;

    GS_dma_stat  curr_stat_e_r,  next_stat_e ;
    
    wire launch_one_word       = out_v_li & out_ready_lo ;

    wire dma_send_finish, dma_all_credit_returned;

    always_comb begin
        case ( curr_stat_e_r )
            eGS_dma_idle :
                if( dma_run_en)                 next_stat_e = eGS_dma_busy;
                else                            next_stat_e = eGS_dma_idle;
            eGS_dma_busy :
                if( dma_send_finish)            next_stat_e = eGS_dma_wait;
                else                            next_stat_e = eGS_dma_busy;
            eGS_dma_wait :
                if( dma_all_credit_returned)    next_stat_e = eGS_dma_signal;
                else                            next_stat_e = eGS_dma_wait;
            eGS_dma_signal:
                if( launch_one_word     )       next_stat_e = eGS_dma_idle ;
                else                            next_stat_e = eGS_dma_signal;
        endcase
    end

    always_ff@( posedge clk_i ) begin
        if( reset_i )  curr_stat_e_r <= eGS_dma_idle;
        else           curr_stat_e_r <= next_stat_e ;
    end
     
    //--------------------------------------------------------------
    //  The 3  Length Counters

     wire [2:0]                      counter_en_li, counter_overflowed_lo;
     wire [2:0][addr_width_p-1 : 0]  counter_lo, counter_limit_li;

     //the accumulated address for each dim
     logic[2:0][addr_width_p-1 : 0]  dim_addr_r, dim_incr, dim_base, dim_finish ; 

     genvar i;

     for(i = 0; i<3; i++) begin
        bsg_counter_dynamic_limit_en#( .width_p ( addr_width_p    )
        ) run_counter (
           .clk_i      ( clk_i                                     )
          ,.reset_i    ( reset_i | dma_run_en                      )
          ,.limit_i    ( counter_limit_li[i]                       )
          ,.en_i       ( counter_en_li   [i]                       )
          ,.counter_o  ( counter_lo      [i]                       )
          ,.overflowed_o(counter_overflowed_lo [i]                 )
        );
        
        if( i== 0) assign counter_en_li[i] =   launch_one_word ;
        else       assign counter_en_li[i] = & counter_overflowed_lo[ i-1 : 0];
        
        assign dim_finish[i]  = counter_en_li[i] & counter_overflowed_lo[i]; 

        always_ff@(posedge clk_i ) begin
                if( reset_i | dma_run_en | dim_finish[i]  )      
                        dim_addr_r[i] <= dim_base[i];
                else if( counter_en_li [i] )    
                        dim_addr_r[i] <= dim_addr_r[i] + dim_incr[i];
        end
    end
    
    wire  epa_order_to[2:0], x_order_to[2:0], y_order_to[2:0];
    for(i=0;i<3;i++) begin
        assign epa_order_to    [i]     = (cmd_order_s.epa_order == i);
        assign x_order_to      [i]     = (cmd_order_s.x_order   == i);
        assign y_order_to      [i]     = (cmd_order_s.y_order   == i);
    end

    for(i=0;i<3;i++)begin
        assign counter_limit_li [ i ]  = (epa_order_to[i])? (src_dim_s.epa32>>2)
                                        :(x_order_to[i]  )?  src_dim_s.x8
                                                          :  src_dim_s.y8;

        assign dim_base         [ i ]  = (epa_order_to[i])? (src_addr_s.epa32>>2)
                                        :(x_order_to[i]  )?  src_addr_s.x8
                                                          :  src_addr_s.y8;

        assign dim_incr         [ i ]  = (epa_order_to[i])? (src_incr_s.epa32>>2)
                                        :(x_order_to[i]  )?  src_incr_s.x8
                                                          :  src_incr_s.y8;
    end

    wire[addr_width_p-1 : 0] epa_send_addr, x_send_addr, y_send_addr;

    assign epa_send_addr = epa_order_to[0] ? dim_addr_r[0]
                          :epa_order_to[1] ? dim_addr_r[1]
                                           : dim_addr_r[2]; 

    assign   x_send_addr =   x_order_to[0] ? dim_addr_r[0]
                          :  x_order_to[1] ? dim_addr_r[1]
                                           : dim_addr_r[2]; 

    assign   y_send_addr =   y_order_to[0] ? dim_addr_r[0]
                          :  y_order_to[1] ? dim_addr_r[1]
                                           : dim_addr_r[2]; 

    assign dma_send_finish = dim_finish[2]; 
    assign dma_all_credit_returned = (curr_stat_e_r == eGS_dma_wait) && ( out_credits_lo == max_out_credits_p );
    //--------------------------------------------------------------
    //  Master interface to load and signal 
    wire   bsg_manycore_packet_payload_u  payload_s;
    
    always_ff@(posedge clk_i) 
        if( reset_i | dma_run_en ) load_id_r <= 'b0            ;
        else                       load_id_r <= load_id_r + 'b1; 

    assign payload_s.load_info_s.load_id=  load_id_r                     ; 

    wire   dma_fetching     =  (curr_stat_e_r == eGS_dma_busy) ;
    wire   dma_signaling    =  (curr_stat_e_r == eGS_dma_signal);

    assign out_v_li         =  dma_fetching  | dma_signaling ;


    assign out_packet_li    = '{
                                 addr        :   dma_fetching ? epa_send_addr :  sig_addr_s.epa32 >> 2
                                ,op          :   dma_fetching ? `ePacketOp_remote_load
                                                              : `ePacketOp_remote_store 
                                ,op_ex       :   {(data_width_p>>3){1'b1}}
                                ,payload     :   dma_fetching ? payload_s     :   data_width_p'(1) 
                                ,src_y_cord  :   my_y_i
                                ,src_x_cord  :   my_x_i
                                ,x_cord      :   dma_fetching ? x_cord_width_p'( x_send_addr   )
                                                              : x_cord_width_p'( sig_addr_s.x8 )
                                ,y_cord      :   dma_fetching ? y_cord_width_p'( y_send_addr   )
                                                              : y_cord_width_p'( sig_addr_s.y8 )
                                };
   //------------------------------------------------------------------
   // Instantiate the memory
   localparam mem_addr_width_lp    = $clog2(dmem_size_p);
   localparam mem_local_port_lp    = 1;
   localparam mem_remote_port_lp   = 0;

   wire [1:0]                                 mem_v_li, mem_we_li, mem_yumi_lo, mem_v_lo;
   wire [1:0] [mem_addr_width_lp-1 : 0]       mem_addr_li;
   wire [1:0] [data_width_p-1      : 0]       mem_data_li, mem_data_lo;
   wire [1:0] [(data_width_p>>3)-1 : 0]       mem_mask_li;

   bsg_mem_banked_crossbar #
    ( .num_ports_p  (2)
     ,.num_banks_p  (1)
     ,.bank_size_p  (dmem_size_p )
     ,.data_width_p (data_width_p)
     // Priority,  0 = fixed hi, 
     ,.rr_lo_hi_p   ( 0 ) 
    ) mem
    (  .clk_i    
      ,.reset_i  
      //deprecated, tied to zero
      ,.reverse_pr_i( 1'b0)
      ,.v_i     (mem_v_li)
      ,.w_i     (mem_we_li)
      ,.addr_i  (mem_addr_li)
      ,.data_i  (mem_data_li)
      ,.mask_i  (mem_mask_li)

      // whether the crossbar accepts the input
     ,.yumi_o  ( mem_yumi_lo)
     ,.v_o     ( mem_v_lo   )
     ,.data_o  ( mem_data_lo)
    );
    //the returned load data 
    assign mem_v_li     [mem_local_port_lp] = returned_v_lo               ; 
    assign mem_we_li    [mem_local_port_lp] = 1'b1                        ;
    assign mem_addr_li  [mem_local_port_lp] = CSR_mem_r[ CSR_DST_ADDR_IDX ] [ 2 +: mem_addr_width_lp ] 
                                            + returned_load_id_r_lo       ;
    assign mem_data_li  [mem_local_port_lp] = returned_data_lo            ;
    assign mem_mask_li  [mem_local_port_lp] = { (data_width_p>>3){1'b1} } ;

    //the request coming from network
    wire is_mem_addr    =  (in_addr_lo >= dmem_size_p ) && ( in_addr_lo < 2*dmem_size_p );

    assign mem_v_li     [mem_remote_port_lp ] =  is_mem_addr & in_v_lo;
    assign mem_we_li    [mem_remote_port_lp ] =  in_we_lo   ;
    assign mem_data_li  [mem_remote_port_lp ] =  in_data_lo ;
    assign mem_addr_li  [mem_remote_port_lp ] =  in_addr_lo ;
    assign mem_mask_li  [mem_remote_port_lp ] =  in_mask_lo ;
   
    //--------------------------------------------------------------
    // assign the signals to endpoint
    assign    in_yumi_li        = in_v_lo & ( is_CSR_addr |  mem_yumi_lo[ mem_remote_port_lp ] ); 
    assign    returning_v_li    = CSR_returning_v_r | mem_v_lo[ mem_remote_port_lp ];

    assign    returning_data_li = CSR_returning_v_r ? CSR_returning_data_r 
                                                    : mem_data_lo[ mem_remote_port_lp ];
    //--------------------------------------------------------------
    // Checking 
    // synopsys translate_off
    always_ff@(negedge clk_i ) begin
        if( in_v_lo &(~ (is_CSR_addr | is_mem_addr ) ) ) begin
                $error("## Invalid CSR addr in Gather/Scatter Module, addr=%h,%t, %m", in_addr_lo<<2 , $time);
                $finish();
        end

        if( 1 ) begin
                
                if( returned_v_lo ) begin
                        $display("## G/S recieved data = %h, load_id = %0d", returned_data_lo, returned_load_id_r_lo);
                end

                //if( dma_all_credit_returned ) $finish();

                if( in_v_lo && is_CSR_addr ) begin
                        if( in_we_lo )
                                $display("## G/S CSR Write: addr=%h, value=%h", in_addr_lo<<2, in_data_lo);  
                        else
                                $display("## G/S CSR Read : addr=%h, value=%h", in_addr_lo<<2, CSR_mem_r[in_addr_lo]);  
                end
        end
    end
    // synopsys translate_on

endmodule
