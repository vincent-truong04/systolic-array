# eco_hold_buffers.tcl: hold-fix ECO on the routed (pre-fill) database by inserting one delay cell
# in front of each listed D pin (the D pin moves to a new net driven by the delay cell; the other
# loads of the original net are untouched), placing it in the nearest free row gap, ripping up the
# affected nets and re-running detailed_route with the ORFS arguments. No existing cell moves.
# Run via `make ... run RUN_SCRIPT=<this>` in an ECO FLOW_VARIANT that is a copy of the design;
# it overwrites 5_2_route.odb there, then `make ... finish`.
# Env: HOLD_TARGETS=<file: "<inst>/D <worst slack>" per line, # comments>
#
# EXP-033-ECO (2026-11-16, Vincent: "Do A"): EXP-033 fails hold at ff (-0.031 nominal, -0.019 ff+min
# RC) and tt (-0.007) on edge-PE a_out/b_out (root-clocked skew regs -> gated flops, ~0.25 ns
# capture-clock delay through the ICG). ORFS repairs hold at ss only. The rerun with
# HOLD_SLACK_MARGIN 0.25 (EXP-034) fixed hold but broke ss+max-RC setup (new clock tree), so the fix
# is a local ECO on EXP-033 instead. Targets: worst slack < 0.03 over ff nom/min/max RC + tt (50).
# Setup slack on these endpoints at ss+max RC is >= 8.64 ns, so a 0.33 ns delay cell is harmless.
# Cell choice per endpoint, most negative slack first (it gets first pick of the nearby gaps):
#   dlygate4sd1_1 (3.22 um; ff ~0.10 ns, ss ~0.33 ns) within 40 um of the D pin,
#   else buf_2 (1.84 um; ff ~0.045) within 40 um, else buf_1 (1.38 um; ff ~0.033) within 60 um.
#   First try used 15/15/20 um: only 18 of 50 placed (the top-edge row-0 PEs and u_skew_b lanes are
#   dense). Distance is harmless for timing here (setup slack >= 8.6 ns; extra wire adds hold delay).

set choices {
  sky130_fd_sc_hd__dlygate4sd1_1 40000
  sky130_fd_sc_hd__buf_2         40000
  sky130_fd_sc_hd__buf_1         60000
}

source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]

set db  [ord::get_db]
set blk [ord::get_db_block]

# New nets need global-route guides, or detailed_route leaves them unrouted (first try). Same
# pattern as ORFS global_route.tcl: start incremental GRT, edit, end incremental GRT (routes only
# the changed nets and writes their guides).
log_cmd source $::env(FASTROUTE_TCL)
log_cmd global_route -start_incremental -allow_congestion

# occupied x-intervals per row y, kept up to date as cells are added
set occ [dict create]
foreach i [$blk getInsts] { set b [$i getBBox]; dict lappend occ [$b yMin] [list [$b xMin] [$b xMax]] }

# nearest site-aligned free gap of width w within maxd (manhattan, DBU) of point (px, py)
proc find_gap {w px py maxd} {
  global occ blk
  set best ""; set bd 1e18
  foreach r [$blk getRows] {
    lassign [$r getOrigin] ox oy
    if {abs($oy-$py) > $maxd} continue
    set site [[$r getSite] getWidth]
    set rx1 [expr {$ox + [$r getSiteCount]*$site}]
    set iv [expr {[dict exists $occ $oy] ? [lsort -integer -index 0 [dict get $occ $oy]] : {}}]
    set x $ox
    foreach v [concat $iv [list [list $rx1 $rx1]]] {
      lassign $v a b
      set lo [expr {$ox + int(ceil(double($x-$ox)/$site))*$site}]
      if {$a - $lo >= $w} {
        set c [expr {$ox + int(round(double($px-$w/2-$ox)/$site))*$site}]
        if {$c < $lo} { set c $lo }
        if {$c + $w > $a} { set c [expr {$ox + int(floor(double($a-$w-$ox)/$site))*$site}] }
        if {$c >= $lo} {
          set d [expr {abs($c+$w/2-$px) + abs($oy-$py)}]
          if {$d < $bd} { set bd $d; set best [list $c $oy [$r getOrient] $d] }
        }
      }
      if {$b > $x} { set x $b }
    }
  }
  if {$best ne "" && [lindex $best 3] <= $maxd} { return $best }
  return ""
}

set targets {}
set fh [open $::env(HOLD_TARGETS)]
while {[gets $fh l] >= 0} {
  if {[string match "#*" $l] || [string trim $l] eq ""} continue
  lappend targets [list [lindex $l 0] [lindex $l 1]]
}
close $fh
set targets [lsort -real -index 1 $targets]

set nets {}
set k 0
set count [dict create]
foreach t $targets {
  lassign $t pin slack
  regsub {/D$} $pin {} iname
  set iname [string map {[ \\[ ] \\]} $iname]
  set inst [$blk findInst $iname]
  if {$inst eq "NULL"} { error "ECO: instance $iname not found" }
  set it [$inst findITerm D]
  set net [$it getNet]
  set pb [$it getBBox]
  set px [expr {([$pb xMin]+[$pb xMax])/2}]; set py [[$inst getBBox] yMin]
  set placed 0
  foreach {mname maxd} $choices {
    set m [$db findMaster $mname]
    set g [find_gap [$m getWidth] $px $py $maxd]
    if {$g eq ""} continue
    lassign $g gx gy orient d
    incr k
    set b [odb::dbInst_create $blk $m HOLD_ECO033_$k]
    $b setOrient $orient
    $b setLocation $gx $gy
    $b setPlacementStatus PLACED
    set nn [odb::dbNet_create $blk hold_eco033_net_$k]
    $it disconnect
    $it connect $nn
    [$b findITerm A] connect $net
    [$b findITerm X] connect $nn
    dict lappend occ $gy [list $gx [expr {$gx+[$m getWidth]}]]
    dict incr count $mname
    puts [format "ECO: HOLD_ECO033_%d %s at (%.2f, %.2f), %.2f um from %s/D (worst slack %s)" \
          $k $mname [expr {$gx/1000.0}] [expr {$gy/1000.0}] [expr {$d/1000.0}] $iname $slack]
    if {[lsearch $nets $net] < 0} { lappend nets $net }
    lappend nets $nn
    set placed 1
    break
  }
  if {!$placed} { error "ECO: no gap for any delay cell near $iname" }
}
puts "ECO: inserted $k cells: $count"
# power/ground pins of the new cells: the design's stored global_connect rules (as for every cell)
global_connect
log_cmd global_route -end_incremental -allow_congestion \
  -congestion_report_file $::env(REPORTS_DIR)/congestion_hold_eco033.rpt

set nrip 0
foreach n $nets { set w [$n getWire]; if {$w ne "NULL"} { odb::dbWire_destroy $w; incr nrip } }
puts "ECO: ripped up $nrip nets ([llength $nets] nets to route)"

set additional_args ""
append_env_var additional_args dbProcessNode -db_process_node 1
append_env_var additional_args OR_SEED -or_seed 1
append_env_var additional_args OR_K -or_k 1
append_env_var additional_args VIA_IN_PIN_MIN_LAYER -via_in_pin_bottom_layer 1
append_env_var additional_args VIA_IN_PIN_MAX_LAYER -via_in_pin_top_layer 1
append_env_var additional_args DISABLE_VIA_GEN -disable_via_gen 0
append_env_var additional_args REPAIR_PDN_VIA_LAYER -repair_pdn_vias 1
append_env_var additional_args DETAILED_ROUTE_END_ITERATION -droute_end_iter 1
append additional_args " -verbose 1"
set all_args [concat [list -output_drc $::env(REPORTS_DIR)/5_route_drc_hold_eco033.rpt \
  -output_maze $::env(RESULTS_DIR)/maze_hold_eco033.log] $additional_args {-drc_report_iter_step 5}]
log_cmd detailed_route {*}$all_args

if { ![design_is_routed] } { error "ECO: design has unrouted nets" }
check_placement -verbose
check_antennas -report_file $::env(REPORTS_DIR)/drt_antennas_hold_eco033.log
orfs_write_db $::env(RESULTS_DIR)/5_2_route.odb
puts "ECO: wrote 5_2_route.odb"
