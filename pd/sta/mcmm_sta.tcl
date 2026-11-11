# Multi-corner STA on a finished ORFS run (post-route, nominal-RC SPEF for all corners).
# Usage: openroad -no_init -exit -threads 8 pd/sta/mcmm_sta.tcl   with env RES=<results dir>
set res  $::env(RES)
set plat $::env(HOME)/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib
set test $::env(HOME)/OpenROAD-flow-scripts/tools/OpenROAD/test/sky130hd
define_corners tt ss ff
read_liberty -corner tt $plat/sky130_fd_sc_hd__tt_025C_1v80.lib
read_liberty -corner ss $test/sky130_fd_sc_hd__ss_n40C_1v40.lib
read_liberty -corner ff $test/sky130_fd_sc_hd__ff_n40C_1v95.lib
read_db   $res/6_final.odb
read_sdc  $res/6_final.sdc
read_spef $res/6_final.spef
foreach c {tt ss ff} {
  puts "=== corner $c"
  puts "setup WNS [format %.3f [sta::worst_slack_cmd max]] (all corners) "
  report_worst_slack -max -corner $c -digits 3
  report_tns -max -digits 3
  report_worst_slack -min -corner $c -digits 3
  puts "setup violators: [llength [sta::endpoint_violation_count max]]"
}
foreach c {tt ss ff} {
  puts "=== $c: worst setup path"
  report_checks -path_delay max -corner $c -format end -group_path_count 3
  puts "=== $c: worst hold path"
  report_checks -path_delay min -corner $c -format end -group_path_count 3
}
puts "=== ss worst setup path (full)"
report_checks -path_delay max -corner ss -digits 3
