# upsize_operand_flops.tcl: PRE_CTS_TCL hook (sourced by ORFS cts.tcl right after it loads
# 3_place.odb). Swaps every dfxtp_1/dfxtp_2 whose Q net has fanout >= UPSIZE_FLOP_MIN_FANOUT
# (default 8) to dfxtp_4.
#
# Why (EXP-018/021/022): every failing setup path starts at an operand register (a_out/b_out,
# the last skew stage, a_q/b_q) driving 8 partial-product gates in the next PE's multiplier
# plus 1 forwarding flop. As dfxtp_1 that is clk->Q ~1.1 ns at ss; repair_timing rarely
# upsizes it. On 3_place.odb at 70% this rule selects ~950 flops: a_out/b_out, u_skew_a/b,
# a_q/b_q, and ~12 high-fanout flag/state flops. CLK pin cap is ~equal for all three sizes
# (1.657/1.657/1.697 fF), so the clock tree sees almost no extra load.
# The CTS step legalizes afterwards (the wider cells overlap until then).

set min_fo 8
if { [info exists ::env(UPSIZE_FLOP_MIN_FANOUT)] } { set min_fo $::env(UPSIZE_FLOP_MIN_FANOUT) }

set db  [ord::get_db]
set big [$db findMaster sky130_fd_sc_hd__dfxtp_4]
set n 0
set area0 0.0
set area1 0.0
foreach inst [[ord::get_db_block] getInsts] {
  set m [$inst getMaster]
  if { [$m getName] ni {sky130_fd_sc_hd__dfxtp_1 sky130_fd_sc_hd__dfxtp_2} } { continue }
  set net [[$inst findITerm Q] getNet]
  if { $net eq "NULL" } { continue }
  if { [llength [$net getITerms]] - 1 < $min_fo } { continue }
  set area0 [expr { $area0 + [$m getWidth] * [$m getHeight] / 1e6 }]
  $inst swapMaster $big
  set area1 [expr { $area1 + [$big getWidth] * [$big getHeight] / 1e6 }]
  incr n
}
puts [format "UPSIZE_FLOPS: %d flops with Q fanout >= %d -> dfxtp_4, area %+.1f um^2" \
  $n $min_fo [expr { $area1 - $area0 }]]
