puts "Info: Start script [info script]\n"

proc bsg_dmc_create_ddr_intf { {prefix ""} } {
  global ddr_intf
  set ddr_intf(ck_p)         [get_pins ${prefix}ddr_ck_p_o]
  set ddr_intf(ck_n)         [get_pins ${prefix}ddr_ck_n_o]
  set ddr_intf(ca)           [get_pins -hier ${prefix}* -filter "name=~ddr_*_o*&&name!~ddr_ck_*&&name!~ddr_dm_*&&name!~ddr_dq*"]
  for {set gid 0} {$gid < 4} {incr gid} { 
    set ddr_intf($gid,dqs_p_i)    [get_pins ${prefix}ddr_dqs_p_i[$gid]]
    set ddr_intf($gid,dqs_p_o)    [get_pins ${prefix}ddr_dqs_p_o[$gid]]
    set ddr_intf($gid,dqs_en_o)   [get_pins ${prefix}ddr_dqs_*_*en_o[$gid]]
    set ddr_intf($gid,dqs_n_i)    [get_pins ${prefix}ddr_dqs_n_i[$gid]]
    set ddr_intf($gid,dqs_n_o)    [get_pins ${prefix}ddr_dqs_n_o[$gid]]
    set ddr_intf($gid,dm_o)       [get_pins ${prefix}ddr_dm_*_o[$gid]]
    for {set i [expr $gid*8]} {$i < [expr ($gid+1)*8]} {incr i} {
      set ddr_intf($gid,dq_i)       [get_pins ${prefix}ddr_dq_i[$i]]
      set ddr_intf($gid,dq_o)       [get_pins ${prefix}ddr_dq_*_o[$i]]
    }
  }
}

############################################
#
# bsg_dmc datapath timing assertions
#
proc bsg_dmc_data_timing_constraints { non_seq_chk id dfi_clk_1x_name dfi_clk_2x_name {prefix ""}} {
  global ddr_intf
  # 
  # dfi_clk_1x and dfi_clk_2x are defined inside bsg_dram_clk_gen
  # we use their sources and cycle time to derive other dram-related clocks
  set dfi_clk_1x_period [expr [lindex [get_db [get_clocks $dfi_clk_2x_name] .period] 0] * 2.0 / 1000.0]
  set dfi_clk_1x_source [get_db [get_clocks $dfi_clk_1x_name] .sources]
  # create input dqs clock
  create_clock -period $dfi_clk_1x_period \
               -name ${prefix}dqs_i_$id    \
               $ddr_intf($id,dqs_p_i)
  create_clock -period $dfi_clk_1x_period \
               -name ${prefix}dqs_n_i_$id    \
               $ddr_intf($id,dqs_n_i)
  #create_clock -period $dfi_clk_1x_period \
  #             -name dqs_i_$id

  set quarter_cycle [expr [lindex [get_db [get_clocks ${prefix}dqs_i_$id] .period] 0] / 4.0 / 1000.0]

  # create 90-degree shifted clock on the output of delay line
  #create_generated_clock -name dqs_i_${id}_dly \
  #                       -edges {1 2 3} \
  #                       -edge_shift [list $quarter_cycle $quarter_cycle $quarter_cycle] \
  #                       -source [get_db [get_clocks dqs_i_$id] .sources] \
  #                       [get_pins -leaf -of_objects [get_nets -hierarchical dqs_p_li[$id]] -filter "direction==out"]
  #create_clock -period $dfi_clk_1x_period \
  #             -name dqs_i_${id}_dly \
  #             -waveform [list $quarter_cycle [expr 3 * $quarter_cycle]] \
  #             [get_pins -leaf -of_objects [get_nets -hierarchical dqs_p_li[$id]] -filter "direction==out"]
  if {[get_cells -quiet -hier *clk_rst_gen] != ""} {
    create_clock -period $dfi_clk_1x_period \
                 -name ${prefix}dqs_i_${id}_dly \
                 -waveform [list $quarter_cycle [expr 3 * $quarter_cycle]] \
                 [get_pins -hier *clk_rst_gen/dqs_clk_o[$id] -filter "direction==out"]
  }
  set max_io_skew_percent 5.0
  set max_io_skew_time [expr $max_io_skew_percent * $dfi_clk_1x_period / 100.0]

  # determin the max and min input delay
  set max_input_delay [expr ($dfi_clk_1x_period / 4.0) - $max_io_skew_time]
  set min_input_delay -$max_input_delay

  # input timing constraints
  # input data (dq) is edge aligned with input clock (dqs) after getting out of dram chips
  # we set 20% of the clock cycle time to account for the misalignment when the signals propagate through the pcb traces and bond wire
  set_input_delay  $max_input_delay $ddr_intf($id,dq_i) -clock [get_clocks ${prefix}dqs_i_$id] -max
  set_input_delay -$max_input_delay $ddr_intf($id,dq_i) -clock [get_clocks ${prefix}dqs_i_$id] -min

  # basically we have two approaches to constrain the output paths
  if { $non_seq_chk } {
  # output timing constraints
  # source synchronous output constraints, similar to comm_link output channels
    foreach_in_collection from_obj $ddr_intf($id,dqs_p_o) {
      foreach_in_collection to_obj [concat $ddr_intf($id,dq_o) $ddr_intf($id,dm_o)] {
        # ideally output clock is center aligned with output data, so the clock has (-25%, +25%) of clock cycle time as the sampling window
        # we deduct 20% from the margin and check if the clock is in the scope of (-5%, +5%) of the data center
        set_data_check -from $from_obj -to $to_obj [expr $dfi_clk_1x_period * 0.2]
        # set_data_check has a default zero cycle checking behavior which need to overcome in this case
        # please take solvnet #024664 as a reference
        set_multicycle_path -end -setup 1 -to $to_obj
        set_multicycle_path -start -hold 0 -to $to_obj
      }
    }
  } else {
    # create generated output dqs clock based on 1x dfi clock
    create_generated_clock -master_clock $dfi_clk_2x_name -divide_by 2 -source [get_db [get_clocks $dfi_clk_2x_name] .sources] -name dqs_p_o_$id -add $ddr_intf($id,dqs_p_o)
    create_generated_clock -master_clock $dfi_clk_2x_name -divide_by 2 -source [get_db [get_clocks $dfi_clk_2x_name] .sources] -name dqs_n_o_$id -add $ddr_intf($id,dqs_n_o)
  
    # determine max and min output delay
    set max_output_delay $max_input_delay
    set min_output_delay $min_input_delay
  
    # similarly we use the output delay values to determin the worst skew between clock and data
    # after they propagate through PCB traces and bond wires so that the data can be sampled
    # correctly at the virtual registers outside the chip
    # max_output_delay means data lags $max_output_delay behind clock
    # min_input_delay means clock lags |$min_input_delay| behind data
    set_output_delay -clock dqs_p_o_$id -max $max_output_delay $ddr_intf($id,dq_o) 
    set_output_delay -clock dqs_p_o_$id -max $max_output_delay $ddr_intf($id,dq_o) -add_delay -clock_fall
    set_output_delay -clock dqs_p_o_$id -min $min_output_delay $ddr_intf($id,dq_o) 
    set_output_delay -clock dqs_p_o_$id -min $min_output_delay $ddr_intf($id,dq_o) -add_delay -clock_fall
 
    set_output_delay -clock dqs_p_o_$id -max $max_output_delay $ddr_intf($id,dm_o) 
    set_output_delay -clock dqs_p_o_$id -max $max_output_delay $ddr_intf($id,dm_o) -add_delay -clock_fall
    set_output_delay -clock dqs_p_o_$id -min $min_output_delay $ddr_intf($id,dm_o) 
    set_output_delay -clock dqs_p_o_$id -min $min_output_delay $ddr_intf($id,dm_o) -add_delay -clock_fall
  }
}

############################################
#
# bsg_dmc address and command path timing assertions
#
proc bsg_dmc_ctrl_timing_constraints { dfi_clk_1x_name dfi_clk_2x_name prefix } {
  global ddr_intf
  #
  # dfi_clk_1x and dfi_clk_2x are defined inside bsg_dram_clk_gen
  # we use their sources and cycle time to derive other dram-related clocks
  set dfi_clk_1x_period [expr [lindex [get_db [get_clocks $dfi_clk_2x_name] .period] 0] * 2.0 / 1000.0]
  set dfi_clk_1x_source [get_db [get_clocks $dfi_clk_1x_name] .sources]
  # create generated clocks to drive dram device, all the address and command signals are synchronous to these clocks
  create_generated_clock -name ${prefix}ddr_ck_p -divide_by 1         -source $dfi_clk_1x_source -master_clock [get_clocks $dfi_clk_1x_name] -add $ddr_intf(ck_p)
  create_generated_clock -name ${prefix}ddr_ck_n -divide_by 1 -invert -source $dfi_clk_1x_source -master_clock [get_clocks $dfi_clk_1x_name] -add $ddr_intf(ck_n)
  # all the address and command signals are registered outputs which are aligned well with clock edges
  # we give it a 10% margin to account for the misalignment caused by PCB traces and bond wires
  set_output_delay [expr  $dfi_clk_1x_period * 0.1] $ddr_intf(ca) -clock [get_clocks ${prefix}ddr_ck_p] -max
  set_output_delay [expr -$dfi_clk_1x_period * 0.1] $ddr_intf(ca) -clock [get_clocks ${prefix}ddr_ck_p] -min
}

puts "Info: Completed script [info script]\n"
