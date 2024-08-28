puts "Info: Start script [info script]\n"

proc bsg_clk_gen_clock_create { osc_path clk_name clk_gen_period_int clk_gen_period_ext osc_uncertainty ds_uncertainty clk_uncertainty} {
  # very little is actually timed with this domain; just the receive
  # side of the bsg_tag_client and the downsampler.
  #
  # Although the fastest target period of the oscillator itself is below
  # this, we don't want this support logic to not be able to keep up
  # in the event that oscillator runs faster than the tools say
  #

  # this is for the output of the downsampler, goes to the clock selection mux
  set clk_gen_period_ds [expr $clk_gen_period_int * 2.0]

  # this is for the output of the oscillator, which goes to the downsampler
  create_clock -period $clk_gen_period_int -name ${clk_name}_osc [get_pins -of_objects [get_db hinsts ${osc_path}clk_gen_osc_inst] -filter "pin_direction==out"]
  set_clock_uncertainty $osc_uncertainty [get_clocks ${clk_name}_osc]

  # Used for internal register clocks not detected by genus
  #create_clock -period $clk_gen_period_ds -name ${clk_name}_adt_int [get_pins -of_objects [get_cells ${osc_path}clk_gen_osc_inst/adt_BSG_DONT_TOUCH/M1] -filter "pin_direction==out"]
  #create_clock -period $clk_gen_period_ds -name ${clk_name}_cdt_int [get_pins -of_objects [get_cells ${osc_path}clk_gen_osc_inst/cdt_BSG_DONT_TOUCH/M1] -filter "pin_direction==out"]
  #create_clock -period $clk_gen_period_ds -name ${clk_name}_fdt_int [get_pins -of_objects [get_cells ${osc_path}clk_gen_osc_inst/fdt_BSG_DONT_TOUCH/M2] -filter "pin_direction==out"]

  # these are generated clocks; we call them clocks to get preferred shielding and routing
  # nothing is actually timed with these
  #create_clock -period $clk_gen_period_ds -name ${clk_name}_osc_ds [get_pins -of_objects [get_cells ${osc_path}clk_gen_ds_inst/clk_r_o_reg] -filter "pin_direction==out"]
  #create_clock -period $clk_gen_period_ds -name ${clk_name}_osc_ds [get_pins -of_objects [get_db hinsts ${osc_path}clk_gen_ds_inst] -filter "pin_direction==out"]
  create_clock -period $clk_gen_period_ds -name ${clk_name}_osc_ds [get_pins -of_objects [get_cells ${osc_path}clk_gen_ds_inst/clk_r_o_reg] -filter "pin_direction==out"]
  set_clock_uncertainty $ds_uncertainty [get_clocks ${clk_name}_osc_ds]

  # the output of the mux is the externally visible bonafide clock
  create_clock -period $clk_gen_period_ext -name ${clk_name} [get_pins -of_objects [get_db hinsts ${osc_path}mux_inst] -filter "pin_direction==out"]
  set_clock_uncertainty $clk_uncertainty [get_clocks ${clk_name}]
}

puts "Info: Completed script [info script]\n"
