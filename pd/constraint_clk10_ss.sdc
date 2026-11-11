# Timing constraints: systolic_top (EXP-012: 10 ns, optimized at ss_100C_1v60, virtual-clock latency)
current_design systolic_top

set clk_name      core_clock
set clk_port_name clk
set clk_period    10.0
set clk_io_pct    0.2

set clk_port [get_ports $clk_port_name]
create_clock -name $clk_name -period $clk_period $clk_port

# Virtual clock: models the external flops that drive our inputs / capture our outputs
set clk_io_name vclk_$clk_name
create_clock -name $clk_io_name -period $clk_period

# External launch/capture flops are assumed to sit on a clock tree like ours,
# so the virtual clock gets the same insertion delay as core_clock.
# 1.9 ns = core_clock insertion delay at ss_100C_1v60 (EXP-011 STA: 1.89 ns).
# Without this, the ideal (0 ns) virtual clock creates false input hold violations.
set_clock_latency 1.9 [get_clocks $clk_io_name]

# 20% of the cycle is assumed spent outside the block on each I/O path
set non_clock_inputs [all_inputs -no_clocks]
set_input_delay  [expr $clk_period * $clk_io_pct] -clock $clk_io_name $non_clock_inputs
set_output_delay [expr $clk_period * $clk_io_pct] -clock $clk_io_name [all_outputs]
