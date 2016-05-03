module test_bsg_vscale_tile;

  localparam hexfile_words_lp = 8192;
  localparam bank_size_lp     = 16384;
  localparam num_banks_lp     = 4;
  localparam fifo_els_lp      = 10;
  localparam dirs_lp          = 4;
  localparam data_width_lp    = 32;
  localparam addr_width_lp    = 32;
  localparam lg_node_x_lp     = 5;
  localparam lg_node_y_lp     = 5;
  localparam packet_width_lp  = 6 + lg_node_x_lp + lg_node_y_lp
                                  + data_width_lp + addr_width_lp;
  localparam cycle_time_lp    = 20;

  // clock and reset generation
  wire clk;
  wire reset;
  
  bsg_nonsynth_clock_gen #( .cycle_time_p(cycle_time_lp)
                          ) clock_gen
                          ( .o(clk)
                          );
    
  bsg_nonsynth_reset_gen #(  .num_clocks_p     (1)
                           , .reset_cycles_lo_p(1)
                           , .reset_cycles_hi_p(5)
                          )  reset_gen
                          (  .clk_i        (clk) 
                           , .async_reset_o(reset)
                          );
  

  reg [127:0]    hexfile [hexfile_words_lp-1:0];
  reg [63:0]     max_cycles;
  reg [63:0]     trace_count;
  reg [63:0]     load_count;
  reg [255:0]    reason;
  reg [1023:0]   loadmem;
  integer        stderr = 32'h80000002;
  
 initial 
  begin
    /*$dumpfile("output.vcd");
    $dumpvars;
    $dumpon;*/
    loadmem = 0;
    reason = 0;
    max_cycles = 0;
    trace_count = 0;
    load_count = 0;
    if ($value$plusargs("max-cycles=%d", max_cycles) && $value$plusargs("loadmem=%s", loadmem))
      begin
	 $readmemh(loadmem, hexfile);
	 $display("loaded %s", loadmem);
      end
    else
      begin
	 $display("both max-cycles and loadmem must be given");
	 $finish;
      end
  end

  logic [dirs_lp-1:0][packet_width_lp-1:0] test_input_data, test_output_data;
  logic [dirs_lp-1:0]                      test_input_valid, test_output_ready
                                           , test_input_yumi, test_output_valid;
  logic                                    htif_pcr_resp_valid;
  logic [`HTIF_PCR_WIDTH-1:0]              htif_pcr_resp_data;
  
  bsg_vscale_tile #
    ( .bank_size_p  (bank_size_lp)
     ,.num_banks_p  (num_banks_lp)
     ,.fifo_els_p   (fifo_els_lp)
     ,.data_width_p (data_width_lp)
     ,.addr_width_p (addr_width_lp)
     ,.dirs_p       (dirs_lp)
     ,.stub_p       (4'b1110)
     ,.lg_node_x_p  (lg_node_x_lp)
     ,.lg_node_y_p  (lg_node_x_lp)
    ) UUT
    ( .clk_i   (clk)
     ,.reset_i (reset)

     ,.packet_i(test_input_data)
     ,.valid_i (test_input_valid)
     ,.ready_o (test_output_ready)

     ,.yumi_i  (test_input_yumi)
     ,.packet_o(test_output_data)
     ,.valid_o (test_output_valid)

     ,.my_x_i  (lg_node_x_lp'(0))
     ,.my_y_i  (lg_node_y_lp'(0))

     ,.htif_pcr_resp_valid_o (htif_pcr_resp_valid)
     ,.htif_pcr_resp_data_o  (htif_pcr_resp_data)
    );

  always_comb
  begin
    test_input_yumi  = {dirs_lp{1'b0}};
    test_input_valid = {{dirs_lp-1{1'b0}}, (~reset) & (load_count <= hexfile_words_lp*4)};

    if(load_count < hexfile_words_lp*4)
      test_input_data[0] = {6'(1)
                            , addr_width_lp'(load_count<<2)
                            , hexfile[load_count>>2][(load_count%4)*32+:32]
                            , 5'(0)
                            , 5'(0)
                           };
    else
      test_input_data[0] = {6'(2)
                            , addr_width_lp'(0)
                            , data_width_lp'(0)
                            , 5'(0)
                            , 5'(0)
                           };
  end

  always @(posedge clk)
  begin
    if(~reset & test_output_ready[0])
      begin
	 load_count = load_count + 1;
	 $display("Sent word %d/%d", load_count,hexfile_words_lp);
      end
  end


  always @(posedge clk) begin
     if (load_count > hexfile_words_lp*4)
       trace_count = trace_count + 1;

     if (max_cycles > 0 && trace_count > max_cycles)
       reason = "timeout";

     if (!reset) begin
        if (htif_pcr_resp_valid && htif_pcr_resp_data != 0) begin
           if (htif_pcr_resp_data == 1) begin
              $display("finished %0s after %0d simulation cycles", loadmem, trace_count); 
              $finish;
           end else begin
              $sformat(reason, "tohost = %d", htif_pcr_resp_data >> 1);
           end
        end
     end


     if (reason) begin
        $error("*** FAILED *** %0s (%s) after %0d simulation cycles", loadmem, reason, trace_count);
        $finish;
     end
  end

endmodule
