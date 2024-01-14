
 module bsg_manycore_vscale_pipeline_trace
      #(parameter x_cord_width_p = "inv"
        , y_cord_width_p = "inv")
 (input clk_i
  , input [31:0] PC_IF
  , input wr_reg_WB
  , input [4:0] reg_to_wr_WB
  , input [31:0] wb_data_WB
  , input stall_WB
  , input imem_wait
  , input dmem_wait
  , input dmem_en
  , input [3:0] exception_code_WB
  , input [31:0] imem_addr
  , input [31:0] imem_rdata
  , input freeze
   ,input   [x_cord_width_p-1:0] my_x_i
   ,input   [y_cord_width_p-1:0] my_y_i
  );

   always @(negedge clk_i)
     begin
        if (~freeze)
          begin
             $fwrite(1,"x=%x y=%x PC_IF=%4.4x imem_wait=%x dmem_wait=%x dmem_en=%x exception_code_WB=%x imem_addr=%x imem_data=%x replay_IF=%x stall_IF=%x stall_DX=%x "
                     ,my_x_i, my_y_i,PC_IF,imem_wait,dmem_wait,dmem_en,exception_code_WB, imem_addr, imem_rdata, ctrl.replay_IF, ctrl.stall_IF, ctrl.stall_DX);
             if (wr_reg_WB & ~stall_WB & (reg_to_wr_WB != 0))
               $fwrite(1,"r[%2.2x]=%x ",reg_to_wr_WB,wb_data_WB);
             $fwrite(1,"\n");
          end
     end
endmodule
