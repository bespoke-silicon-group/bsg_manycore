// bsg_manycore_tag_adaptor
// 09/20/2016  shawnless.xie@gmail.com

//This module converts parallel valid /data 
//into serial tag bit patterns.


module   bsg_manycore_tag_adaptor
   #(
     parameter width_p  = "inv"  //the payload width
   , parameter els_p    = "inv"  //how many clients 

   , parameter lg_els_p = `BSG_SAFE_CLOG2( els_p+1 )
   , parameter lg_width_p = `BSG_SAFE_CLOG2( width_p+1 )
   , parameter init_cycle_p = 16 //the cycle should wait after reset

   , parameter target_reset_cycle_p = 16
   , parameter lg_target_reset_cycle_lp =`BSG_SAFE_CLOG2(target_reset_cycle_p+1)
     //the cycle should wait after reset
   , parameter lg_init_cycle_p = `BSG_SAFE_CLOG2( init_cycle_p+1)
   ) (
    input   clk_i      
   ,input   reset_i    
   ,output logic  tag_clk_o  
   ,output logic  tag_en_o   
   ,output logic  tag_data_o 

   ,input                   v_i        
   ,input[width_p-1:0]      data_i     
   ,output logic            ready_o    

   //which nodes do you want to inject ?
   ,input[lg_els_p-1:0]     nodeID_i

   // tag_adaptor will output a reset signal, which is supposed to 
   // reset the target desgin. This reset signal only asserts after
   // all tag_clients have been reseted.
   ,output                  target_reset_o 
   );

  initial
    $display("tag_adaptor:  width_p =%d (%b), ", width_p, width_p);

  `declare_bsg_tag_header_s( els_p, lg_width_p )

  localparam tag_pkt_size_lp = 1 + $bits(bsg_tag_header_s)+ width_p +1;

  localparam tag_rst_size_lp = `bsg_tag_reset_len( els_p, lg_width_p );  

  //////////////////////////////////////////////////////////////////////////////////
  //counter for the transmittion
  localparam lg_master_rst_size_lp = `BSG_SAFE_CLOG2( tag_rst_size_lp );
  localparam lg_client_size_lp     = `BSG_SAFE_CLOG2( tag_pkt_size_lp );
  //extra bit for overflow
  logic [lg_master_rst_size_lp:0]  master_reset_counter_r; 


  //extra bit for overflow
  logic [lg_client_size_lp:0]     client_data_counter_r;
  wire client_data_counter_full = client_data_counter_r == tag_pkt_size_lp-1;


  //extra bit for overflow
  logic [lg_client_size_lp:0]      client_reset_counter_r; 
  wire client_reset_counter_full = client_reset_counter_r == tag_pkt_size_lp-1;


  logic [lg_els_p-1: 0]            reset_nodeID_r;
  wire  client_reset_done = ( reset_nodeID_r == els_p-1) & client_reset_counter_full;

  //extra bit for overflow
  logic [lg_init_cycle_p:0] init_counter_r;

  //target reset counter
  logic [lg_target_reset_cycle_lp-1:0] target_reset_counter_r;

  //////////////////////////////////////////////////////////////////////////////////
  //the state machine 
  typedef enum logic[2:0] 
         { eInit, eIdle, eMaster_reset, eClients_reset, eTarget_reset, eTransimit} adapter_stat_enum; 

  adapter_stat_enum curr_stat_r, next_stat;

  always_ff@( posedge clk_i )
  begin
    if( reset_i) curr_stat_r <= eInit;
    else         curr_stat_r <= next_stat;
  end

  always_comb
  begin
    unique case( curr_stat_r )
        eInit:
           if( init_counter_r < init_cycle_p )  next_stat = eInit;
           else                                 next_stat = eMaster_reset; 
        eMaster_reset:
          if( master_reset_counter_r < tag_rst_size_lp ) next_stat =eMaster_reset;
          else                                           next_stat =eClients_reset;
        eClients_reset:
          if( client_reset_done ) next_stat = eTarget_reset;
          else                    next_stat = eClients_reset;
        eTarget_reset:
          if( target_reset_counter_r == target_reset_cycle_p)
                next_stat = eIdle;
          else
                next_stat = eTarget_reset;
        eTransimit:
          if( client_data_counter_full) next_stat = eIdle;
          else                          next_stat = eTransimit;
        eIdle:
          if( v_i ) next_stat = eTransimit;
          else      next_stat = eIdle;
    endcase 
  end 
/*
  always@( next_stat  ) 
  begin
     $display("Tag_adaptor:  %d   ====>   %d", curr_stat_r, next_stat);
  end
*/
  //////////////////////////////////////////////////////////////////////////////////
  //update the init_counter_r 
  always_ff@(posedge clk_i )
  begin
    if( reset_i) 
        init_counter_r <= 'b0;
    else if( init_counter_r < init_cycle_p) 
        init_counter_r <= init_counter_r + 1;
  end

  //////////////////////////////////////////////////////////////////////////////////
  //update the master_reset_counter_r 
  always_ff@(posedge clk_i) 
  begin
    if( reset_i )   master_reset_counter_r <= 'b0;
    else if ( curr_stat_r == eMaster_reset ) 
                    master_reset_counter_r = master_reset_counter_r + 1; 
  end 

  //////////////////////////////////////////////////////////////////////////////////
  //update the client_data_counter_r
  always_ff@(posedge clk_i )
  begin
    if( reset_i ) client_data_counter_r    <= 'b0;
    else if( client_data_counter_r == tag_pkt_size_lp ) 
        client_data_counter_r    <= 'b0;
    else if( curr_stat_r == eTransimit )
        client_data_counter_r    <= client_data_counter_r + 1;
  end

  //////////////////////////////////////////////////////////////////////////////////
  //update the client_reset_counter_r
  always_ff@(posedge clk_i )
  begin
    if( reset_i ) client_reset_counter_r  <= 'b0;
    else if(   curr_stat_r == eClients_reset )
       client_reset_counter_r <= client_reset_counter_r + 1;
  end

  //////////////////////////////////////////////////////////////////////////////////
  //update the target_reset_counter_r
  always_ff@(posedge clk_i)
  begin
    if( reset_i ) target_reset_counter_r  <= 'b0;
    else if( curr_stat_r == eTarget_reset) 
        target_reset_counter_r  <= target_reset_counter_r +1;
  end

  //////////////////////////////////////////////////////////////////////////////////
  //update the reset_nodeID_r 
  always_ff@(posedge clk_i)
  begin
    if( reset_i) reset_nodeID_r  <= 'b0;
    else if( curr_stat_r == eClients_reset  && client_reset_counter_full)
                 reset_nodeID_r  <= reset_nodeID_r + 1;
  end  
            
  //////////////////////////////////////////////////////////////////////////////////
  //construct the serial packat
  bsg_tag_header_s data_header_n, reset_header_n;
  logic [tag_pkt_size_lp-1:0] data_pkt_r, reset_pkt_r; 

  ///////////////////// client reset shift register
  assign reset_header_n = '{nodeID:reset_nodeID_r, data_not_reset: 1'b0, len:width_p};
  wire [tag_pkt_size_lp-1:0] reset_pkt_n = { 1'b0, {width_p{1'b1}}, reset_header_n,1'b1 };

  always_ff@(posedge clk_i ) 
  begin
    if( reset_i ) 
      reset_pkt_r <= reset_pkt_n ;
    else if ( curr_stat_r == eClients_reset )
      if( client_reset_counter_full ) //finish one client reset
        reset_pkt_r <= reset_pkt_n;
      else                            //reseting one client 
        reset_pkt_r <= reset_pkt_r >> 1;
  end 
 
  ///////////////////// data transmitting shift register
  assign data_header_n  = '{nodeID: nodeID_i, data_not_reset:1'b1, len:width_p};
  wire [tag_pkt_size_lp-1:0] data_pkt_n  = { 1'b0, data_i, data_header_n,1'b1 };

  always_ff@(posedge clk_i )
  begin
    if( reset_i)  
        data_pkt_r  <= 'b0;
    //Latch the input data to the shift register
    else if( curr_stat_r != eTransimit  && next_stat == eTransimit )
        data_pkt_r  <= data_pkt_n;
    //shifting the register
    else if( curr_stat_r == eTransimit  && next_stat == eTransimit )
        data_pkt_r  <= data_pkt_r >>1;
  end

  //////////////////////////////////////////////////////////////////////////////////
  //output
  always_comb 
  begin
    tag_data_o = 1'b0;
    if(curr_stat_r == eInit && next_stat == eMaster_reset )
        tag_data_o = 1'b1;
    else if( curr_stat_r == eMaster_reset  )
        tag_data_o = 1'b0;
    else if( curr_stat_r == eClients_reset )
        tag_data_o = reset_pkt_r[0];
    else if( curr_stat_r == eTransimit )
        tag_data_o = data_pkt_r[0]; 
  end 

//  assign  tag_en_o = 1'b1; 
  assign  tag_en_o = next_stat   == eTransimit;
  assign  ready_o  = curr_stat_r == eIdle;
  assign  tag_clk_o= clk_i;
//  assign  target_reset_o  = curr_stat_r == eTarget_reset;
  assign  target_reset_o  = 1'b0;

endmodule
