# Timing constraints: systolic_top (EXP-004: clock push to 7.0 ns)
current_design systolic_top

set clk_name      core_clock
set clk_port_name clk
set clk_period    7.0
set clk_io_pct    0.2

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port

# Virtual clock: models the external flops that drive our inputs / capture our outputs
set clk_io_name vclk_$clk_name
create_clock -name $clk_io_name -period $clk_period

# 20% of the cycle is assumed spent outside the block on each I/O path
set non_clock_inputs [all_inputs -no_clocks]
set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_io_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_io_name [all_outputs]
