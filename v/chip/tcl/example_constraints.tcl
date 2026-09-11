

if {[info exists env(TOOL)]} {
  set TOOL $::env(TOOL)/
} else {
  set TOOL "innovus"
}


######################################################
## Source common scripts
######################################################
source -echo -verbose $::env(CHIP_TCL_DIR)/bsg_async.constraints.tcl
source -echo -verbose $::env(CHIP_TCL_DIR)/bsg_cdc.constraints.tcl
source -echo -verbose $::env(CHIP_TCL_DIR)/bsg_misc.constraints.tcl
source -echo -verbose $::env(CHIP_TCL_DIR)/bsg_link_sdr.constraints.tcl

######################################################
## Clock Setup
######################################################

set osc_name           "osc"
set osc_period_ns      0.250 ; # 4 GHz
set osc_uncertainty_ns 0.020

set core_clk_name "core_clk" ; # main clock running DUT
set core_clk_period_ns          1.25
set core_clk_uncertainty_per    3
set core_clk_uncertainty_max_ns 0.020
set core_clk_uncertainty_ns     [expr min([expr $core_clk_period_ns*$core_clk_uncertainty_per/100.0],$core_clk_uncertainty_max_ns)]

set core_input_delay_min_per 2
set core_input_delay_min_ns  [expr $core_clk_period_ns*$core_input_delay_min_per/100.0]
set core_input_delay_max_per 60
set core_input_delay_max_ns  [expr $core_clk_period_ns*$core_input_delay_max_per/100.0]

set core_output_delay_min_per 2
set core_output_delay_min_ns  [expr $core_clk_period_ns*$core_output_delay_min_per/100.0]
set core_output_delay_max_per 20
set core_output_delay_max_ns  [expr $core_clk_period_ns*$core_output_delay_max_per/100.0]

set link_clk_period_ns        1.0
set link_clk_uncertainty_per  3.0
set link_clk_uncertainty_ns  [expr min([expr $link_clk_period_ns*($link_clk_uncertainty_per/100.0)], 20)]

set token_clk_period_ns       [expr 2*$link_clk_period_ns]
set token_clk_uncertainty_per 3.0
set token_clk_uncertainty_ns  [expr min([expr $token_clk_period_ns*($token_clk_uncertainty_per/100.0)], 20)]

set max_io_output_margin_ns   0.30
set max_io_input_margin_ns    0.30

set tag_clk_name "tag_clk"
set tag_clk_period_ns 5
set tag_clk_uncertainty_ns 0.020

set tag_input_delay_min_ns 0.500
set tag_input_delay_max_ns 4

######################################################
## Reg2Reg
######################################################

create_clock -period $core_clk_period_ns -name $core_clk_name [get_pins -hier *clk_gen/clk_o]
set_clock_uncertainty $core_clk_uncertainty_ns [get_clocks $core_clk_name]

create_clock -period $tag_clk_period_ns -name $tag_clk_name [get_ports tag_clk_i]
set_clock_uncertainty $tag_clk_uncertainty_ns [get_clocks $tag_clk_name]

######################################################
## In2Reg
######################################################
set tag_input_pins [filter_collection [get_ports tag*] "full_name!~*clk_i"]
set_input_delay -min $tag_input_delay_min_ns -clock $tag_clk_name $tag_input_pins
set_input_delay -max $tag_input_delay_max_ns -clock $tag_clk_name $tag_input_pins

set_input_delay 0 -clock $core_clk_name [get_ports ext_clk_i]
set_input_delay 0 -clock $core_clk_name [get_ports async_fwd_link_o_disable_i[*][*]]
set_input_delay 0 -clock $core_clk_name [get_ports async_fwd_link_i_disable_i[*][*]]
set_input_delay 0 -clock $core_clk_name [get_ports async_rev_link_o_disable_i[*][*]]
set_input_delay 0 -clock $core_clk_name [get_ports async_rev_link_i_disable_i[*][*]]
set_input_delay 0 -clock $core_clk_name [get_ports async_clk_output_disable_i]

set_driving_cell -min -no_design_rule -lib_cell INVD8BWP7T40P140 [all_inputs]
set_driving_cell -max -no_design_rule -lib_cell INVD2BWP7T40P140 [all_inputs]

######################################################
## Reg2Out
######################################################
set core_output_pins {}
append_to_collection core_output_pins [get_ports clk_monitor_o]

set_output_delay -min $core_output_delay_min_ns -clock $core_clk_name $core_output_pins
set_output_delay -max $core_output_delay_max_ns -clock $core_clk_name $core_output_pins

set_load -max [load_of [get_lib_pin INVD8BWP7T40P140/I]] $core_output_pins
set_load -min [load_of [get_lib_pin INVD2BWP7T40P140/I]] $core_output_pins

######################################################
## Feedthrough
######################################################
set feedthrough_input_pins {}

set feedthrough_output_pins {}

#set_output_delay -min 0.020 $feedthrough_output_pins -clock $core_clk_name
#set_output_delay -max 0.020 $feedthrough_output_pins -clock $core_clk_name

######################################################
## SDR constraints
######################################################
set sdr_clocks [list]
for {set i 1} {$i <= 2} {incr i} {
  for {set j 3} {$j <= 4} {incr j} {
    for {set k 0} {$k < 2} {incr k} {
      bsg_link_sdr_constraints                                                 \
        $core_clk_name                                                         \
        [get_pins -hier *clk_gen/clk_o]                                        \
        "mem_out_clk[$i][$j][$k]"                                              \
        $core_clk_period_ns                                                    \
        $max_io_output_margin_ns                                               \
        [get_ports "mem_link_clk_o[$i][$j][$k]"]                               \
        [get_ports "mem_link_data_o[$i][$j][$k][*] mem_link_v_o[$i][$j][$k]"]  \
        "mem_out_tkn_clk[$i][$j][$k]"                                          \
        [get_ports "mem_link_token_o[$i][$j][$k]"]                             \
        "mem_in_clk[$i][$j][$k]"                                               \
        $link_clk_period_ns                                                    \
        $max_io_input_margin_ns                                                \
        [get_ports "mem_link_clk_i[$i][$j][$k]"]                               \
        [get_ports "mem_link_data_i[$i][$j][$k][*] mem_link_v_i[$i][$j][$k]"]  \
        "mem_in_tkn_clk[$i][$j][$k]"                                              \
        [get_ports "mem_link_token_i[$i][$j][$k]"]                             \
        $link_clk_uncertainty_ns

        append_to_collection sdr_clocks "mem_out_clk[$i][$j][$k]"
        append_to_collection sdr_clocks "mem_out_tkn_clk[$i][$j][$k]"
        append_to_collection sdr_clocks "mem_in_clk[$i][$j][$k]"
        append_to_collection sdr_clocks "mem_in_tkn_clk[$i][$j][$k]"
    }
  }
}

for {set i 1} {$i <= 2} {incr i} {
  for {set j 0} {$j < 12} {incr j} {
    bsg_link_sdr_constraints                                               \
      $core_clk_name                                                       \
      [get_pins -hier *clk_gen/clk_o]                                      \
      "io_fwd_out_clk[$i][$j]"                                             \
      $core_clk_period_ns                                                  \
      $max_io_output_margin_ns                                             \
      [get_ports "io_fwd_link_clk_o[$i][$j]"]                              \
      [get_ports "io_fwd_link_data_o[$i][$j][*] io_fwd_link_v_o[$i][$j]"]  \
      "io_fwd_out_tkn_clk[$i][$j]"                                         \
      [get_ports "io_fwd_link_token_o[$i][$j]"]                            \
      "io_fwd_in_clk[$i][$j]"                                              \
      $link_clk_period_ns                                                  \
      $max_io_input_margin_ns                                              \
      [get_ports "io_fwd_link_clk_i[$i][$j]"]                              \
      [get_ports "io_fwd_link_data_i[$i][$j][*] io_fwd_link_v_i[$i][$j]"]  \
      "io_fwd_in_tkn_clk[$i][$j]"                                          \
      [get_ports "io_fwd_link_token_i[$i][$j]"]                            \
      $link_clk_uncertainty_ns

      append_to_collection sdr_clocks "io_fwd_out_clk[$i][$j]"
      append_to_collection sdr_clocks "io_fwd_out_tkn_clk[$i][$j]"
      append_to_collection sdr_clocks "io_fwd_in_clk[$i][$j]"
      append_to_collection sdr_clocks "io_fwd_in_tkn_clk[$i][$j]"
  }
}

for {set i 1} {$i <= 2} {incr i} {
  for {set j 0} {$j < 12} {incr j} {
    bsg_link_sdr_constraints                                               \
      $core_clk_name                                                       \
      [get_pins -hier *clk_gen/clk_o]                                      \
      "io_rev_out_clk[$i][$j]"                                             \
      $core_clk_period_ns                                                  \
      $max_io_output_margin_ns                                             \
      [get_ports "io_rev_link_clk_o[$i][$j]"]                              \
      [get_ports "io_rev_link_data_o[$i][$j][*] io_rev_link_v_o[$i][$j]"]  \
      "io_rev_out_tkn_clk[$i][$j]"                                         \
      [get_ports "io_rev_link_token_o[$i][$j]"]                            \
      "io_rev_in_clk[$i][$j]"                                              \
      $link_clk_period_ns                                                  \
      $max_io_input_margin_ns                                              \
      [get_ports "io_rev_link_clk_i[$i][$j]"]                              \
      [get_ports "io_rev_link_data_i[$i][$j][*] io_rev_link_v_i[$i][$j]"]  \
      "io_rev_in_tkn_clk[$i][$j]"                                         \
      [get_ports "io_rev_link_token_i[$i][$j]"]                            \
      $link_clk_uncertainty_ns

      append_to_collection sdr_clocks "io_rev_out_clk[$i][$j]"
      append_to_collection sdr_clocks "io_rev_out_tkn_clk[$i][$j]"
      append_to_collection sdr_clocks "io_rev_in_clk[$i][$j]"
      append_to_collection sdr_clocks "io_rev_in_tkn_clk[$i][$j]"
  }
}

######################################################
## Disable timing
######################################################
set_case_analysis 0 [get_ports async_fwd_link_o_disable_i[*][*]]
set_case_analysis 0 [get_ports async_fwd_link_i_disable_i[*][*]]
set_case_analysis 0 [get_ports async_rev_link_o_disable_i[*][*]]
set_case_analysis 0 [get_ports async_rev_link_i_disable_i[*][*]]
bsg_link_sdr_disable_timing_constraints
bsg_link_sdr_dont_touch_constraints [get_ports {io_fwd_link_data_i[*][*][*] io_fwd_link_v_i[*][*]}]
bsg_link_sdr_dont_touch_constraints [get_ports {io_rev_link_data_i[*][*][*] io_rev_link_v_i[*][*]}]
bsg_link_sdr_dont_touch_constraints [get_ports {mem_link_data_i[*][*][*] mem_link_v_i[*][*]}]

set hard_inv_cells [get_cells -hier -filter "name=~*hard_inv*"]
set hard_buf_cells [get_cells -hier -filter "name=~*hard_buf*"]
set_dont_touch $hard_inv_cells true
set_dont_touch $hard_buf_cells true
set_dont_touch [get_nets -of [get_pins -of $hard_inv_cells -filter "name==I"]] true
set_dont_touch [get_nets -of [get_pins -of $hard_inv_cells -filter "name==ZN"]] true
set_dont_touch [get_nets -of [get_pins -of $hard_buf_cells -filter "name==I"]] true
set_dont_touch [get_nets -of [get_pins -of $hard_buf_cells -filter "name==Z"]] true

# multicycle cells
set multicycle_cells [list]

# manycore_tiles
append_to_collection multicycle_cells [get_cells -hier *tile/dff_x_data_r_reg_*]
append_to_collection multicycle_cells [get_cells -hier *tile/dff_y_data_r_reg_*]

# vcache
append_to_collection multicycle_cells [get_cells -hier *vc/x_dff_data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *vc/y_dff_data_r_reg*]

# sdr north ()
append_to_collection multicycle_cells [get_cells -hier *sdr_n/dff_global_x/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_n/dff_global_y/data_r_reg*]

# sdr corner ()
append_to_collection multicycle_cells [get_cells -hier *sdr_nw/dff_global_x/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_nw/dff_global_y/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_ne/dff_global_x/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_ne/dff_global_y/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_sw/dff_global_x/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_sw/dff_global_y/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_se/dff_global_x/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_se/dff_global_y/data_r_reg*]

# sdr_west east
append_to_collection multicycle_cells [get_cells -hier *sdr_e/dff_global_x/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_e/dff_global_y/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_w/dff_global_x/data_r_reg*]
append_to_collection multicycle_cells [get_cells -hier *sdr_w/dff_global_y/data_r_reg*]

set_multicycle_path 2 -setup -to   $multicycle_cells
set_multicycle_path 1 -hold  -to   $multicycle_cells
set_multicycle_path 2 -setup -from $multicycle_cells
set_multicycle_path 1 -hold  -from $multicycle_cells

set_case_analysis 0 [get_ports tag_node_id_offset_i[*]]

######################################################
## CDC paths
######################################################
set cdc_clocks [remove_from_collection [all_clocks] $sdr_clocks]
bsg_async_icl $cdc_clocks

foreach {s} $sdr_clocks {
  set cdc_clocks [list]
  bsg_async_two_clocks $core_clk_period_ns [get_clocks $s] [get_clocks $core_clk_name]
  bsg_async_two_clocks $core_clk_period_ns [get_clocks $s] [get_clocks $tag_clk_name]
}

######################################################
## Derate
######################################################
#bsg_derate_cells
#bsg_derate_mems
bsg_sync_constraints

######################################################
## Ungrouping
######################################################

######################################################
## Retiming
######################################################

#if {$TOOL == "genus"} {
#  set_driving_cell -no_design_rule -lib_cell "PDDW12DGZ_H_G" -pin C [all_inputs]
#  set_load [load_of [get_lib_pin "PDDW12DGZ_H_G/I"]] [all_outputs]
#} else {
#  # set_driving_cell -no_design_rule -lib_cell "PDDW12DGZ_H_G" -pin C [all_inputs]
#  set_driving_cell -no_design_rule -lib_cell PDDW12DGZ_H_G -pin C -from_pin PAD \
#    -input_transition_rise 0.5  -input_transition_fall 0.5  [all_inputs]
#  set_load [lindex [get_db [get_lib_pin "*/PDDW12DGZ_H_G/I"] .fanout_load] 0] [all_outputs]
#}

