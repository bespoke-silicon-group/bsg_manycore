package vanilla_scoreboard_tracker_pkg;

  // integer scoreboard
  typedef enum logic [31:0] {
    e_vanilla_isb_remote_group_load
    ,e_vanilla_isb_remote_global_load
    ,e_vanilla_isb_remote_dram_load
    ,e_vanilla_isb_idiv
    ,e_vanilla_isb_n
  } vanilla_isb_type_e;

  // floating point scoreboard
  typedef enum logic [31:0] {
    e_vanilla_fsb_remote_group_load
    ,e_vanilla_fsb_remote_global_load
    ,e_vanilla_fsb_remote_dram_load
    ,e_vanilla_fsb_fdiv_fsqrt
    ,e_vanilla_fsb_n
  } vanilla_fsb_type_e;

endpackage // vanilla_scoreboard_tracker_pkg
