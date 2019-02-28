/**
 *  bsg_manycore_link_to_cce_mgmt.v
 *
 *  @author tommy
 */

module bsg_manycore_link_to_cce_mgmt
  #(parameter link_data_width_p="inv"
    , parameter link_addr_width_p="inv"
    , parameter freeze_init_p="inv"
    , localparam link_mask_width_lp=(link_data_width_p>>3)
  )
  (
    input clk_i
    , input reset_i

    // bp side
    , output logic reset_o
    , output logic freeze_o

    // manycore side
    , input v_i
    , input [link_data_width_p-1:0] data_i
    , input [link_mask_width_lp-1:0] mask_i
    , input [link_addr_width_p-1:0] addr_i
    , input we_i
    , output logic yumi_o
    
    , output logic [link_data_width_p-1:0] data_o
    , output logic v_o
  );


  logic reset_r, reset_n;
  logic freeze_r, freeze_n;

  typedef enum logic [1:0] {
    WAIT
    ,WRITE_DATA
    ,READ_DATA
    ,SEND_RESP
  } mgmt_state_e;

  mgmt_state_e mgmt_state_r, mgmt_state_n;
  logic [link_addr_width_p-1:0] addr_r, addr_n;
  logic [link_data_width_p-1:0] data_r, data_n;
  logic [link_mask_width_lp-1:0] mask_r, mask_n;
  logic [link_data_width_p-1:0] resp_data_r, resp_data_n;

  logic is_config_addr;
  logic is_freeze_addr;
  logic is_reset_addr;

  assign is_config_addr = addr_r[link_addr_width_p-1];
  assign is_freeze_addr = is_config_addr & (addr_r[0+:link_addr_width_p-1] == (link_addr_width_p-1)'(1)); 
  assign is_reset_addr = is_config_addr & (addr_r[0+:link_addr_width_p-1] == (link_addr_width_p-1)'(0));

  always_comb begin
    mgmt_state_n = mgmt_state_r;
    freeze_n = freeze_r;
    reset_n = reset_r;
    addr_n = addr_r;
    data_n = data_r;
    mask_n = mask_r;
    resp_data_n = resp_data_r;
    yumi_o = 1'b0;
    v_o = 1'b0;

    case (mgmt_state_r)
      WAIT: begin
        if (v_i) begin
          addr_n = addr_i;
          data_n = we_i
            ? data_i
            : data_r;
          mask_n = mask_i;
          yumi_o = 1'b1;
          mgmt_state_n = we_i
            ? WRITE_DATA
            : READ_DATA;
        end
      end

      WRITE_DATA: begin
        mgmt_state_n = SEND_RESP;

        if (is_freeze_addr) begin
          freeze_n = data_r[0];
          mgmt_state_n = SEND_RESP;
        end

        if (is_reset_addr) begin
          reset_n = data_r[0];
          mgmt_state_n = SEND_RESP;
        end

        resp_data_n = '0;
      end

      READ_DATA: begin
        mgmt_state_n = SEND_RESP;
        if (is_freeze_addr) begin
          resp_data_n = {{(link_data_width_p-1){1'b0}}, freeze_r};
          mgmt_state_n = SEND_RESP;
        end

        if (is_reset_addr) begin
          resp_data_n = {{(link_data_width_p-1){1'b0}}, reset_r};
          mgmt_state_n = SEND_RESP;
        end

      end
      
      SEND_RESP: begin
        v_o = 1'b1;
        mgmt_state_n = WAIT;
      end 
    endcase
  end

  assign reset_o = reset_r;
  assign freeze_o = freeze_r;
  assign data_o = resp_data_r;
  
  // sequential
  //
  always_ff @ (posedge clk_i) begin
    if (reset_i) begin
      reset_r <= 1'b0;
      freeze_r <= freeze_init_p;
      mgmt_state_r <= WAIT;
    end
    else begin
      reset_r <= reset_n;
      freeze_r <= freeze_n;
      mgmt_state_r <= mgmt_state_n;
      addr_r <= addr_n;
      data_r <= data_n;
      mask_r <= mask_n;
      resp_data_r <= resp_data_n;
    end
  end

endmodule
