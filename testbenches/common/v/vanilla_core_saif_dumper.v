module vanilla_core_saif_dumper
  import bsg_manycore_pkg::*;
  import bsg_vanilla_pkg::*;
  import bsg_manycore_profile_pkg::*;
  #(parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"
    , parameter data_width_p="inv"

    , parameter icache_tag_width_p="inv"
    , parameter icache_entries_p="inv"
    , parameter origin_x_cord_p="inv"
    , parameter origin_y_cord_p="inv"

    , parameter icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , parameter pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)

    , parameter reg_els_lp = RV32_reg_els_gp
    , parameter reg_addr_width_lp = RV32_reg_addr_width_gp
  )
  (
    input clk_i
    , input reset_i
    , input exe_signals_s exe_r

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i

    , input  saif_en_i 
    , output saif_en_o 
  );

  wire trigger_s = (exe_r.instruction ==? `SAIF_TRIGGER_S);
  wire trigger_e = (exe_r.instruction ==? `SAIF_TRIGGER_E);
  
  logic out = 0;
  assign saif_en_o = out;

  always_comb begin
    if(trigger_s) begin
      if(!saif_en_i) begin
        $display("TRIGGER_ON(%d,%d)",my_x_i,my_y_i);
        $set_gate_level_monitoring("rtl_on");
        $set_toggle_region(manycore_tb_top.network.manycore);
        $toggle_start();
      end
      out= 1'b1;
      $display("TRIGGER_S: i=%b,o=%b(%d,%d)",saif_en_i,saif_en_o,my_x_i,my_y_i);
    end

    if (trigger_e) begin
      out= 1'b0;
      if(!saif_en_i) begin
        $display("TRIGGER_OFF(%d,%d)",my_x_i,my_y_i);
        $toggle_stop();
        $toggle_report("run.saif", 1.0e-12, manycore_tb_top.network.manycore);
      end
      $display("TRIGGER_E: i=%b,o=%b(%d,%d)",saif_en_i,saif_en_o,my_x_i,my_y_i);
    end
  end
  
endmodule
