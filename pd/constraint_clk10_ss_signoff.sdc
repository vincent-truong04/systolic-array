# Timing constraints: systolic_top (EXP-013: EXP-012 + signoff margins; values approved by Vincent 2026-11-11)
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

# --- Signoff margins (textbook values, not foundry numbers) -------------------
# Clock uncertainty: jitter + margin for effects not modelled (no RC corners, etc.)
set_clock_uncertainty -setup 0.25 [get_clocks $clk_name]
set_clock_uncertainty -hold  0.05 [get_clocks $clk_name]
# On-chip variation: early paths 5% faster, late paths 5% slower (cells and nets)
set_timing_derate -early 0.95
set_timing_derate -late  1.05
