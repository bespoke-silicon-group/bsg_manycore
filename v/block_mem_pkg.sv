package block_mem_pkg;
  typedef enum logic [3:0] {
    e_store,
    e_lbu,
    e_lhu,
    e_lb,
    e_lh,
    e_lw,
    e_nop
  } block_mem_op_e;
endpackage
