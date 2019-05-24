/**
 *    vanilla_core.v
 *
 */


module vanilla_core
  #(parameter data_width_p="inv"
    , parameter dmem_size_p="inv"
    
    , parameter icache_entries_p="inv"
    , parameter icache_tag_width_p="inv"

    , parameter x_cord_width_p="inv"
    , parameter y_cord_width_p="inv"

    , localparam icache_addr_width_lp=`BSG_SAFE_CLOG2(icache_entries_p)
    , localparam pc_width_lp=(icache_tag_width_p+icache_addr_width_lp)
  )
  (
    input clk_i
    , input reset_i

    , input [pc_width_lp-1:0] pc_init_val_i

    , input icache_v_i
    , input [pc_width_lp-1:0] icache_pc_i
    , input [data_width_p-1:0] icache_instr_i
    
    , input ifetch_v_i
    , input [pc_width_lp-1:0] ifetch_pc_i
    , input [data_width_p-1:0] ifetch_instr_i
  
    , output remote_req_s remote_req_o
    , output logic remote_req_v_o
    , input remote_req_yumi_i

    , input remote_load_resp_s remote_load_resp_i
    , input remote_load_resp_v_i
    , input remote_load_resp_force_i
    , output logic remote_load_resp_yumi_o

    , input [x_cord_width_p-1:0] my_x_i
    , input [y_cord_width_p-1:0] my_y_i
  );





endmodule
