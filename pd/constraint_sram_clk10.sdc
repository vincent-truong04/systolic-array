# Timing constraints: systolic_sram_top (EXP-035 DRAFT; copy of constraint_clk10_ss_signoff.sdc, only current_design changed). Original header: systolic_top (EXP-013: EXP-012 + signoff margins; values approved by Vincent 2026-11-11)
current_design systolic_sram_top

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

# --- Weight-buffer macro (D-018), NOT yet decided: -------------------------------------------
# The macro .lib is OpenRAM's analytical TT model (min period 0.094 ns, clk->dout1 0.33-0.47 ns,
# output transitions 2-16 ps): not credible numbers, and TT only while the logic is timed at ss.
# dout1 is modeled from the falling clock edge, so STA does see the half-cycle path to u_core b_q.
# Whether to add margin on macro paths (e.g. a late derate on u_bbuf) is Vincent's decision after
# the first STA; nothing is added here.
