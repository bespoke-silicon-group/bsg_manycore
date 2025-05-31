puts "BSG-info: Running script [info script]\n"

proc bsg_async_icl {clocks} {

  foreach_in_collection launch_clk $clocks {
    if { [get_db $launch_clk .is_generated] } {
      set launch_group [get_generated_clocks -quiet -filter "master_clock==[get_db $launch_clk .master_clock]"]
      append_to_collection launch_group [get_db $launch_clk .master_clock]
    } else {
      set launch_group [get_generated_clocks -quiet -filter "master_clock==[get_db $launch_clk .name]"]
      append_to_collection launch_group $launch_clk
    }
  
    foreach_in_collection latch_clk [remove_from_collection $clocks $launch_group] {
      set launch_period [expr [get_db $launch_clk .period] / 1000.0]
      set latch_period [expr [get_db $latch_clk .period] / 1000.0]
      set max_delay_ns [expr min($launch_period,$latch_period)/2]
      set_max_delay $max_delay_ns -from $launch_clk -to $latch_clk -ignore_clock_latency
      set_min_delay 0             -from $launch_clk -to $latch_clk -ignore_clock_latency
    }
  }
}

proc bsg_sync_constraints {} {
  foreach_in_collection s1 [get_pins -quiet -of_objects [get_cells -quiet -hier *hard_sync_int1_BSG_SYNC*] -filter "name=~D"] {
    set_false_path -to $s1 -setup
    set_false_path -to $s1 -hold
  }
}

puts "BSG-info: Completed script [info script]\n"
