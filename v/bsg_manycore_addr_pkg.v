/**
 *    bsg_manycore_addr_pkg.v
 *
 *    Manycore address constants
 */

package bsg_manycore_addr_pkg;

  // NPA prefixes
  parameter bsg_dram_npa_prefix_gp = 32'h8000_0000;
  parameter bsg_io_npa_prefix_gp   = 32'h4000_0000;

  // IO EPA (word address)
  parameter bsg_saif_start_addr_gp = 16'hfff0;
  parameter bsg_saif_end_addr_gp = 16'hfff4;


  parameter bsg_heartbeat_init_epa_gp = 16'hbea0;
  parameter bsg_heartbeat_iter_epa_gp = 16'hbea4;
  parameter bsg_heartbeat_end_epa_gp = 16'hbea8;

  parameter bsg_finish_epa_gp       = 16'head0;
  parameter bsg_time_epa_gp         = 16'head4;
  parameter bsg_fail_epa_gp         = 16'head8;
  parameter bsg_stdout_epa_gp       = 16'headc;
  parameter bsg_stderr_epa_gp       = 16'heee0;
  parameter bsg_branch_trace_epa_gp = 16'heee4;
  parameter bsg_print_stat_epa_gp   = 16'h0d0c;

  parameter bsg_finish_npa_gp       = bsg_io_npa_prefix_gp | 32'(bsg_finish_epa_gp      );
  parameter bsg_time_npa_gp         = bsg_io_npa_prefix_gp | 32'(bsg_time_epa_gp        );
  parameter bsg_fail_npa_gp         = bsg_io_npa_prefix_gp | 32'(bsg_fail_epa_gp        );
  parameter bsg_stdout_npa_gp       = bsg_io_npa_prefix_gp | 32'(bsg_stdout_epa_gp      );
  parameter bsg_stderr_npa_gp       = bsg_io_npa_prefix_gp | 32'(bsg_stderr_epa_gp      );
  parameter bsg_branch_trace_npa_gp = bsg_io_npa_prefix_gp | 32'(bsg_branch_trace_epa_gp);

endpackage
