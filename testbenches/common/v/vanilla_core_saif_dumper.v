/* 
 * The vanilla_core_saif_dumper is a bind module that attaches to the
 * vanilla core. It observes instructions in the execution stage and
 * sets saif_en_o to 1 when SAIF_TRIGGER_START is executed (see
 * v/vanilla_bean/bsg_vanilla_pkg.v for instruction definition) and sets
 * saif_en_o to 0 when SAIF_TRIGGER_END is executed.
 * 
 * If SAIF_TRIGGER_START is executed and saif_en_i is 0, then this
 * module calls functions to start tracking toggling for saif
 * generation.
 *
 * If SAIF_TRIGGER_END is executed and saif_en_i is 0, then this
 * module calls functions to write run.saif
 *
 */
module vanilla_core_saif_dumper
  import bsg_manycore_pkg::*;
   import bsg_vanilla_pkg::*;
   import bsg_manycore_profile_pkg::*;
   #(parameter debug_p = 1 // Turns on display statments
     )
   (input clk_i
    , input reset_i
    , input stall_all
    , input exe_signals_s exe_r

    , input  saif_en_i 
    , output saif_en_o 
    );

   logic trigger_start_l = (exe_r.instruction ==? `SAIF_TRIGGER_START) & ~stall_all;
   logic trigger_end_l = (exe_r.instruction ==? `SAIF_TRIGGER_END) & ~stall_all;
   
   logic out = 0;
   assign saif_en_o = out;

   always_comb begin
      if(trigger_start_l) begin
         if(!saif_en_i) begin
            if(debug_p)
              $display("TRIGGER_ON (%m)");
            $set_gate_level_monitoring("rtl_on", "sv");
            $set_toggle_region(`HOST_MODULE_PATH.testbench.DUT);
            $toggle_start();
         end
         out = 1'b1;
         if(debug_p)
           $display("TRIGGER_S: i=%b,o=%b (%m)",saif_en_i,saif_en_o);
      end

      if (trigger_end_l) begin
         out = 1'b0;
         if(!saif_en_i) begin
            if(debug_p)
              $display("TRIGGER_OFF(%m)");
            $toggle_stop();
            $toggle_report("run.saif", 1.0e-12, `HOST_MODULE_PATH.testbench.DUT);
         end
         if(debug_p)
           $display("TRIGGER_E: i=%b,o=%b (%m)",saif_en_i,saif_en_o);
      end
   end
   
endmodule
