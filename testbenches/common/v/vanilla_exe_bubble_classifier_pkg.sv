package vanilla_exe_bubble_classifier_pkg;

  typedef enum logic [31:0] {
    e_exe_bubble_branch_miss,
    e_exe_bubble_jalr_miss,
    e_exe_bubble_icache_miss,

    e_exe_bubble_stall_depend_dram,
    e_exe_bubble_stall_depend_seq_dram,
    e_exe_bubble_stall_depend_dram_amo,
    e_exe_bubble_stall_depend_global,
    e_exe_bubble_stall_depend_group,
    e_exe_bubble_stall_depend_fdiv,
    e_exe_bubble_stall_depend_idiv,

    e_exe_bubble_stall_depend_long_op,

    e_exe_bubble_stall_depend_local_load,
    e_exe_bubble_stall_depend_imul,

    e_exe_bubble_stall_amo_aq,
    e_exe_bubble_stall_amo_rl,

    e_exe_bubble_stall_bypass,
    e_exe_bubble_stall_lr_aq,
    e_exe_bubble_stall_fence,

    e_exe_bubble_stall_remote_req,
    e_exe_bubble_stall_remote_credit,

    e_exe_bubble_stall_fdiv_busy,
    e_exe_bubble_stall_idiv_busy,
    e_exe_bubble_stall_fcsr,
    e_exe_bubble_stall_barrier,

    e_exe_no_bubble
  } exe_bubble_type_e;

endpackage // vanilla_exe_bubble_classifier_pkg
  
