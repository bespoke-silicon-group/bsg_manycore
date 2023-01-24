/* 
 * The vanilla_core_saif_dumper is a bind module that attaches to the
 * vanilla core. It observes instructions in the execution stage and
 * sets saif_en_o to 1 when SAIF_TRIGGER_START is executed (see
 * v/vanilla_bean/bsg_vanilla_pkg.v for instruction definition) and sets
 * saif_en_o to 0 when SAIF_TRIGGER_END is executed.
 * 
 * saif_en_i comes from the module that declares the bind statment. It
 * should be 1 if any vanilla_core_saif_dumper module has saif_en_o
 * set to 1 and 0 otherwise.
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
  #(parameter debug_p = 1 // Turns on display statments
    )
  (input clk_i
   , input reset_i
   , input stall_all
   , input exe_signals_s exe_r

   , input  saif_en_i
   , output logic saif_en_o
   );

   wire trigger_start = (exe_r.instruction ==? `SAIF_TRIGGER_START) & ~stall_all;
   wire trigger_end = (exe_r.instruction ==? `SAIF_TRIGGER_END) & ~stall_all;

   logic saif_en_r;

   always @ (negedge clk_i) begin
      if (reset_i) begin
         saif_en_o <= 1'b0;
         saif_en_r <= 1'b0;
      end
      else begin
         saif_en_r <= saif_en_i;

         if(trigger_start) begin
            saif_en_o <= 1'b1;
            if(debug_p)
              $display("TRIGGER_START: i=%b, o=%b, r=%b t=%t (%m)",saif_en_i,saif_en_o, saif_en_o, $time);
         end

         if (trigger_end) begin
            saif_en_o <= 1'b0;
            if(debug_p)
              $display("TRIGGER_END: i=%b,o=%b t=%t (%m)", saif_en_i, saif_en_o, $time);
         end

      end
   end // always @ (posedge clk_i)

   always @(posedge clk_i) begin
      if(saif_en_i ^ saif_en_r) begin
         if(trigger_start) begin
            if(debug_p)
              $display("TRIGGER_ON t=%t (%m)", $time);
            $set_gate_level_monitoring("rtl_on", "sv");
           $set_toggle_region(`HOST_MODULE_PATH.testbench.fi1.DUT);
            $toggle_start();
         end
         if(trigger_end) begin
            if(debug_p)
              $display("TRIGGER_OFF t=%t (%m)", $time);
            $toggle_stop();
           $toggle_report("run.saif", 1.0e-12, `HOST_MODULE_PATH.testbench.fi1.DUT);
         end
      end // if (saif_en_i ^ saif_en_r)
   end // always @ (negedge clk_i)

endmodule
