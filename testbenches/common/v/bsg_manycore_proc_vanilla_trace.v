/**
 *  bsg_manycore_proc_vanilla_trace
 *  
 *  trace format:
 *
 *  <timestamp> <tileXY> <PC> <INSTR>
 */


module bsg_manycore_proc_vanilla_trace
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter icache_tag_width_p="inv"
    , parameter icache_entries_p="inv"
    , parameter data_width_p="inv"
    , parameter dmem_size_p="inv"

    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam mem_width_lp=`BSG_SAFE_CLOG2(dmem_size_p)
    , localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
  )
  (
    input clk_i
    , input reset_i

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i 

    , input CSR_FREEZE_r
    
    , input [1:0] xbar_port_v_in
    , input [1:0] xbar_port_we_in
    , input [1:0] xbar_port_yumi_out
    , input [1:0][data_width_p-1:0] xbar_port_data_in
    , input [1:0][mem_width_lp-1:0] xbar_port_addr_in
    , input [1:0][(data_width_p>>3)-1:0] xbar_port_mask_in
    , input [data_width_p-1:0] core_mem_rdata
    , input [data_width_p-1:0] load_returning_data
  );


  integer fd;

  logic remote_load_v_r;
  logic [mem_width_lp-1:0] remote_load_addr_r;

  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
        remote_load_v_r <= 1'b0;
        remote_load_addr_r <= '0;
    end
    else begin
        remote_load_v_r <= xbar_port_v_in[0] & ~xbar_port_we_in[0] & xbar_port_yumi_out[0];
        remote_load_addr_r <= xbar_port_addr_in[0];
    end
  end
 
  initial begin

    fd = $fopen("vanilla.log", "w");
    $fwrite(fd, "");
    $fclose(fd);

    forever begin
      @(negedge clk_i) begin
        // we only trace when tile is unfrozen.
        if (~CSR_FREEZE_r) begin
        
          fd = $fopen("vanilla.log", "a");
   
          // timestamp
          $fwrite(fd, "%08t ", $time); 

          // x,y
          $fwrite(fd, "%2d %2d ", my_x_i, my_y_i);
          
          // pc_r, instruction
          $fwrite(fd, "%08x %08x ",
            {{32-pc_width_lp-2{1'b0}}, bsg_manycore_proc_vanilla.vanilla_core.pc_r, 2'b00},
            bsg_manycore_proc_vanilla.vanilla_core.instruction,
          );

          // regfile write
          if (bsg_manycore_proc_vanilla.vanilla_core.rf_wen) begin
            $fwrite(fd, "x%02d=%08x ",
              bsg_manycore_proc_vanilla.vanilla_core.rf_wa,
              bsg_manycore_proc_vanilla.vanilla_core.rf_wd
            );
          end
          else begin
            $fwrite(fd, "             ");
          end

          if (xbar_port_v_in[0] & xbar_port_we_in[0] & xbar_port_yumi_out[0]) begin // remote store
            $fwrite(fd, "RS[%08x]=%08x "
              , {{(data_width_p-2-mem_width_lp){1'b0}},xbar_port_addr_in[0], 2'b00}
              , xbar_port_data_in[0]
            );
          end

          if (remote_load_v_r) begin
            $fwrite(fd, "RL[%08x]=%08x "
              , {{(data_width_p-2-mem_width_lp){1'b0}},remote_load_addr_r, 2'b00}
              , load_returning_data
            );
          end

          if (xbar_port_v_in[1] & xbar_port_we_in[1] & xbar_port_yumi_out[1]) begin // local store
             
          end


          $fwrite(fd, "\n");


          $fclose(fd);
      
        end
      end
    end


  end 



endmodule
