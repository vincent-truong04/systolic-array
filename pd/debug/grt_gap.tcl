# grt_gap.tcl: where does slack go in the global-route step after repair_timing?
# Runs the unchanged ORFS global_route.tcl with Tcl traces and prints WNS/TNS after each
# of the flow's own estimate_parasitics calls (#1 after global_route, #2 after
# repair_design, #3 after repair_timing + incremental legalize/reroute, #4 after
# repair_antennas = stage metric), plus right after repair_timing, and the worst path at #3/#4.
# Only standard report commands are used: find_timing_paths/get_property inside these
# traces segfaulted OpenROAD (2026-11-12).
# Run via `make ... run RUN_SCRIPT=<this>` in a scratch FLOW_VARIANT holding a copy of
# 4_cts.odb/.sdc (global_route.tcl writes 5_1_grt.odb into that RESULTS_DIR).
# Output: grep -E "^GG|^worst slack|^tns|slack \(" <log>

set ::gg_n 0
proc gg_est_leave { args } {
  incr ::gg_n
  puts "GG after flow estimate_parasitics #$::gg_n"
  report_worst_slack -max -digits 3
  report_tns -digits 3
  if { $::gg_n >= 3 } {
    report_checks -path_delay max -group_path_count 1 -fields {fanout cap slew} -digits 3
  }
}
proc gg_rt_leave { args } {
  puts "GG after repair_timing"
  report_worst_slack -max -digits 3
  report_tns -digits 3
}

trace add execution estimate_parasitics leave gg_est_leave
trace add execution repair_timing leave gg_rt_leave

source $::env(SCRIPTS_DIR)/global_route.tcl
