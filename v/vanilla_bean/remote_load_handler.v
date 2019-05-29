/**
 *  remote_load_handler.v
 *
 */

`include "definitions.vh"
`include "parameters.vh"

module remote_load_handler
  #(parameter data_width_p="inv"
    , parameter reg_addr_width_p=RV32_reg_addr_width_gp
  )
  (
    // from network
    input remote_load_resp_s remote_load_resp_i
    , input remote_load_resp_v_i
    , input remote_load_resp_force_i
    , output logic remote_load_resp_yumi_o

    // for float WB
    , output logic [data_width_p-1:0] fp_remote_load_data_o  
    , output logic fp_remote_load_v_o
  
    // for int WB
    , output logic [data_width_p-1:0] int_remote_load_data_o
    , output logic int_remote_load_v_o
    , output logic int_remote_load_force_o
    , input int_remote_load_yumi_i
  );


  // load packer for int load
  //
  logic [data_width_p-1:0] int_load_data;

  load_packer lp0 (
    .mem_data_i(remote_load_resp_i.data)
    ,.unsigned_load_i(remote_load_resp_i.is_unsigned_op)
    ,.byte_load_i(remote_load_resp_i.is_byte_op)
    ,.hex_load_i(remote_load_resp_i.is_hex_op)
    ,.part_sel_i(remote_load_resp_i.part_sel)
    ,.load_data_o(int_load_data)
  );

  assign int_remote_load_data_o = int_load_data;
  assign fp_remote_load_data_o = remote_load_resp_i.data;


  // if it's float_wb, it's accepted right away.
  // if it's int wb, it can be inserted in EXE-MEM, if available.
  // Otherwise it waits until force_i. If force_i and EXE-MEM is not
  // available, then it forces write-back to regfile.
  always_comb begin
    if (remote_load_resp_i.float_wb) begin
      fp_remote_load_v_o = remote_load_resp_v_i;
      remote_load_resp_yumi_o = remote_load_resp_v_i;
      int_remote_load_v_o = 1'b0;
      int_remote_load_force_o = 1'b0;
    end
    else begin
      fp_remote_load_v_o = 1'b0;
      if (remote_load_resp_force_i) begin
        int_remote_load_v_o = remote_load_resp_v_i;
        int_remote_load_force_o = remote_load_resp_v_i & ~int_remote_load_yumi_i;
        remote_load_resp_yumi_o = 1'b1;
      end
      else begin
        int_remote_load_v_o = remote_load_resp_v_i;
        int_remote_load_force_o = 1'b0;
        remote_load_resp_yumi_o = int_remote_load_yumi_i;
      end
    end
  end


endmodule
