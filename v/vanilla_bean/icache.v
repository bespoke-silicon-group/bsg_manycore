//====================================================================
// icache.v
// 05/11/2018, shawnless.xie@gmail.com
//====================================================================
// Instruction cache for manycore. 

`include "parameters.vh"
`include "definitions.vh"
module icache #(parameter 
                          icache_tag_width_p     = -1, 
                          icache_addr_width_p    = -1,
                          //word address
                          pc_width_lp            = icache_tag_width_p + icache_addr_width_p, 
                          icache_format_width_lp = `icache_format_width( icache_tag_width_p )
               )
               (
                input                              clk_i
               ,input                              reset_i

               ,input                              icache_cen_i
               ,input                              icache_w_en_i
                //TODO: The written address should be enlarged. 
                //      WORD address now
               ,input [icache_addr_width_p-1:0]    icache_w_addr_i
               ,input [icache_tag_width_p -1:0]    icache_w_tag_i
               ,input [RV32_instr_width_gp-1:0]    icache_w_instr_i
               ,output[RV32_instr_width_gp-1:0]    instruction_o

               ,input [pc_width_lp-1:0]            pc_i
               ,input                              pc_wen_i
               ,output [pc_width_lp-1:0]           pc_r_o
               ,output [pc_width_lp-1:0]           jump_addr_o
               ,output                             icache_miss_o
               );

  //the struct fo be written into the icache
  `declare_icache_format_s( icache_tag_width_p );
  icache_format_s       icache_w_data_s, icache_r_data_s, icache_stall_out_r, icache_stall_out;

  //the address of the icache entry
  wire [icache_addr_width_p-1:0]  icache_addr = icache_w_en_i ? icache_w_addr_i
                                                              : pc_i[0+:icache_addr_width_p];
  //------------------------------------------------------------------
  //
  //  Pre-compute the lower part of the jump address for JAL and BRANCH
  //  instruction
  //
  //  The width of the adder is defined by the Imm width +1.
  //------------------------------------------------------------------
  instruction_s   w_instr;

  assign w_instr      = icache_w_instr_i;

  wire  write_branch_instr = ( w_instr.op    ==? `RV32_BRANCH );
  wire  write_jal_instr    = ( w_instr       ==? `RV32_JAL    );
  
  // TODO -- Re-factoring the ring packet so it can have full Imm bits address.
  // BYTE address computation
  localparam branch_pc_low_width_lp = (RV32_Bimm_width_gp+1);
  localparam jal_pc_low_width_lp    = (RV32_Jimm_width_gp+1);

  localparam branch_pc_high_width_lp = (pc_width_lp+2) - branch_pc_low_width_lp; 
  localparam jal_pc_high_width_lp    = (pc_width_lp+2) - jal_pc_low_width_lp;

  wire  [branch_pc_low_width_lp-1:0] branch_imm_val     = `RV32_Bimm_13extract(w_instr);
  wire  [branch_pc_low_width_lp-1:0] branch_pc_val      = branch_pc_low_width_lp'({icache_w_tag_i,icache_w_addr_i,2'b0}); 
  
  wire  [jal_pc_low_width_lp-1:0] jal_imm_val        = `RV32_Jimm_21extract(w_instr);
  wire  [jal_pc_low_width_lp-1:0] jal_pc_val         = jal_pc_low_width_lp'({icache_w_tag_i, icache_w_addr_i,2'b0}); 
  
  wire  [branch_pc_low_width_lp-1:0] branch_pc_lower_res;
  wire  [jal_pc_low_width_lp-1:0]    jal_pc_lower_res;
  wire  branch_pc_lower_cout, jal_pc_lower_cout;
  
  assign {branch_pc_lower_cout, branch_pc_lower_res} = {1'b0, branch_imm_val} + {1'b0, branch_pc_val};
  assign {jal_pc_lower_cout,    jal_pc_lower_res   } = {1'b0, jal_imm_val}    + {1'b0, jal_pc_val   };
  
  
  //Inject the 2-BYTE address, the LSB is ignored.
  wire [RV32_instr_width_gp-1:0] injected_instr =
          write_branch_instr ? `RV32_Bimm_12inject1( w_instr, branch_pc_lower_res)
                             :  write_jal_instr    ? `RV32_Jimm_20inject1(w_instr, jal_pc_lower_res)
                                                   : w_instr;

  wire imm_sign = write_branch_instr ? branch_imm_val[RV32_Bimm_width_gp] 
                                     : jal_imm_val   [RV32_Jimm_width_gp];

  wire pc_lower_cout = write_branch_instr ? branch_pc_lower_cout
                                          : jal_pc_lower_cout;

  
  assign icache_w_data_s = '{lower_sign:       imm_sign         ,
                             lower_cout:       pc_lower_cout    ,
                             tag       :       icache_w_tag_i  ,
                             instr     :       injected_instr
                            };
                             
  //------------------------------------------------------------------
  // Instantiate the memory 
  bsg_mem_1rw_sync #
    ( .width_p ( icache_format_width_lp )
     ,.els_p   (2**icache_addr_width_p)
     //,.substitute_1r1w_p(1'b0)
    ) imem_0
    ( .clk_i  (clk_i)
     ,.reset_i(reset_i)
     ,.v_i    (icache_cen_i)
     ,.w_i    (icache_w_en_i)
     ,.addr_i (icache_addr)
     ,.data_i (icache_w_data_s)
     ,.data_o (icache_r_data_s)
    );

  logic [pc_width_lp-1:0]  pc_r; 
  logic                    pc_wen_r;

  // Since imem has one cycle delay and we send next cycle's address, pc_n,
  // if the PC is not written, the instruction must not change.
  always_ff@(posedge clk_i) 
        if(reset_i)        pc_wen_r           <= 'b0;
        else               pc_wen_r           <= pc_wen_i;

  always_ff@(posedge clk_i) 
        if(reset_i)        pc_r               <= 'b0;
        else if( pc_wen_i) pc_r               <= pc_i;

  always_ff@(posedge clk_i) 
        if(reset_i)          icache_stall_out_r    <= 'b0;
        else                 icache_stall_out_r    <= icache_stall_out;

  //this is the final output that send out, take stall into consideration
  assign icache_stall_out = (pc_wen_r) ? icache_r_data_s: icache_stall_out_r;
  //------------------------------------------------------------------
  // Merge the PC lower part and high part
  // BYTE operations
  wire [branch_pc_high_width_lp-1:0]  branch_pc_high    = pc_r[ (branch_pc_low_width_lp-2)+: branch_pc_high_width_lp];
  wire [branch_pc_high_width_lp-1:0]  branch_pc_high_p1 = branch_pc_high + 1'b1; 
  wire [branch_pc_high_width_lp-1:0]  branch_pc_high_n1 = branch_pc_high + {branch_pc_high_width_lp{1'b1}}; 
  wire [branch_pc_high_width_lp-1:0]  branch_pc_high_out;

  wire [jal_pc_high_width_lp-1:   0]  jal_pc_high       = pc_r[ (jal_pc_low_width_lp-2)+: jal_pc_high_width_lp ];
  wire [jal_pc_high_width_lp-1:   0]  jal_pc_high_p1    = jal_pc_high + 1'b1;
  wire [jal_pc_high_width_lp-1:   0]  jal_pc_high_n1    = jal_pc_high + {jal_pc_high_width_lp{1'b1}};
  wire [jal_pc_high_width_lp-1:   0]  jal_pc_high_out ;

  //   pc_lower_sign    pc_lower_cout   pc_high-1       pc_high      pc_high+1
  //        0                 0                             1                   
  //        0                 1                                          1
  //        1                 0           1                                     
  //        1                 1                             1 
  wire sel_pc           = ~(icache_stall_out.lower_sign    ^ icache_stall_out.lower_cout) ; 
  wire sel_pc_p1        = (~icache_stall_out.lower_sign) & icache_stall_out.lower_cout ; 
  wire sel_pc_n1        = icache_stall_out.lower_sign    & (~icache_stall_out.lower_cout) ; 

  bsg_mux_one_hot #( .els_p      (3                      )
                    ,.width_p    (branch_pc_high_width_lp)
                   )branch_pc_high_mux
                  ( .data_i        ( {branch_pc_high, branch_pc_high_p1, branch_pc_high_n1} )
                   ,.sel_one_hot_i ( {sel_pc        , sel_pc_p1,         sel_pc_n1        } )
                   ,.data_o        ( branch_pc_high_out                                  )
                  );

  bsg_mux_one_hot #( .els_p      (3                      )
                    ,.width_p    (jal_pc_high_width_lp   )
                   )jal_pc_high_mux
                  ( .data_i        ( {jal_pc_high, jal_pc_high_p1, jal_pc_high_n1} )
                   ,.sel_one_hot_i ( {sel_pc     , sel_pc_p1,      sel_pc_n1     } )
                   ,.data_o        ( jal_pc_high_out               )
                  );

  wire is_jal_instr     = icache_stall_out.instr ==? `RV32_JAL  ;

  //these are bytes address
  wire [pc_width_lp+1:0] jal_pc    = {jal_pc_high_out,    `RV32_Jimm_21extract(icache_stall_out.instr) };
  wire [pc_width_lp+1:0] branch_pc = {branch_pc_high_out, `RV32_Bimm_13extract(icache_stall_out.instr) };
  //------------------------------------------------------------------
  // assign outputs.
  assign instruction_o = icache_stall_out.instr;
  assign pc_r_o        = pc_r;
  // jump_addr_o is WORD address
  assign jump_addr_o      = is_jal_instr ? jal_pc[2+:pc_width_lp] : branch_pc[2+:pc_width_lp];
  // the icache miss logic
  assign icache_miss_o    =  ( icache_stall_out.tag != pc_r[icache_addr_width_p+:icache_tag_width_p] );
  
endmodule
