puts "Info: Start script [info script]\n"

proc bsg_chip_async_constraints {} {
  set generated_clocks [get_generated_clocks]
  foreach_in_collection clk [get_clocks -filter "!is_generated"] {
    set clk_grp $clk
    set clk_name [get_db [get_clocks $clk] .name]
    append_to_collection clk_grp [get_generated_clocks -filter "master_clock==$clk_name"]
    set_clock_groups -asynchronous -group $clk_grp
  }
}

proc bsg_chip_cdc_constraints { clks } {
  foreach_in_collection clk $clks {
    set clk_name [get_db [get_clocks $clk] .name]
    set cdc_clk_name ${clk_name}_cdc
    set cdc_clk_period [expr [get_db [get_clocks $clk] .period] / 1000.0]
    set cdc_clk_source [get_db [get_clocks $clk] .sources]
    create_clock -name $cdc_clk_name -period $cdc_clk_period -add $cdc_clk_source
  }

  foreach_in_collection cdc_clk [get_clocks *_cdc] {
    set_false_path -from $cdc_clk -to $cdc_clk
  }

  set_clock_groups -physically_exclusive \
                   -group $clks \
                   -group [get_clocks *_cdc]

  foreach_in_collection cdc_clk0 [get_clocks *_cdc] {
    foreach_in_collection cdc_clk1 [remove_from_collection [get_clocks *_cdc] $cdc_clk0] {
      set cdc_delay [lindex [lsort -real [expr [get_db [get_clocks "$cdc_clk0 $cdc_clk1"] .period] / 1000.0] 0]
      set_max_delay $cdc_delay -from $cdc_clk0 -to $cdc_clk1
      set_min_delay 0.0        -from $cdc_clk0 -to $cdc_clk1
    }
  }
}

proc bsg_async_two_clocks {period clk0 clk1} {
  set max_delay_ns [expr $period/2]
  set_max_delay $max_delay_ns -from $clk0 -to $clk1 -ignore_clock_latency
  set_min_delay 0             -from $clk0 -to $clk1 -ignore_clock_latency
  set_max_delay $max_delay_ns -from $clk1 -to $clk0 -ignore_clock_latency
  set_min_delay 0             -from $clk1 -to $clk0 -ignore_clock_latency
}

puts "Info: Completed script [info script]\n"
