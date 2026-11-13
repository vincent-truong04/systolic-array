# legalize_gap.tcl: does legalization undo repair_timing in the CTS step?
# Runs the unchanged ORFS cts.tcl, with Tcl traces that measure slack and cell
# positions around repair_timing and the detailed_placement (legalizer) after it.
# Run via `make ... run RUN_SCRIPT=<this>` in a scratch FLOW_VARIANT holding a copy
# of 3_place.odb/.sdc (cts.tcl writes 4_1_cts.odb into that RESULTS_DIR).

proc gap_measure { tag } {
  estimate_parasitics -placement
  set wns [sta::worst_slack -max]
  set tns [sta::total_negative_slack -max]
  set nviol 0
  foreach p [all_registers -data_pins] {
    if { [get_property $p slack_max] < 0 } { incr nviol }
  }
  puts [format "GAP %-28s WNS %+.3f  TNS %8.3f  failing D pins %d" $tag $wns $tns $nviol]
}

proc gap_snapshot {} {
  set pos [dict create]
  foreach i [[ord::get_db_block] getInsts] {
    dict set pos [$i getName] [$i getLocation]
  }
  return $pos
}

# Slack of the worst path, plus each cell on it and how far the legalizer moved it.
proc gap_worst_path { tag {before {}} } {
  set pe [lindex [find_timing_paths -path_delay max -group_path_count 1] 0]
  puts [format "GAP %s worst path -> %s  slack %+.3f" $tag \
    [get_full_name [get_property $pe endpoint]] [get_property $pe slack]]
  set seen {}
  foreach pt [get_property $pe points] {
    set inst [sta::sta_to_db_inst [[get_property $pt pin] instance]]
    set n [$inst getName]
    if { $n in $seen } { continue }
    lappend seen $n
    set mv ""
    if { [dict exists $before $n] } {
      lassign [dict get $before $n] x0 y0
      lassign [$inst getLocation] x1 y1
      set mv [format "moved %.2f um" [expr { (abs($x1 - $x0) + abs($y1 - $y0)) / 1000.0 }]]
    }
    puts [format "GAP     %-55s %-22s %s" $n [[$inst getMaster] getName] $mv]
  }
}

# Displacement of all cells by one legalization (Manhattan, um; DBU = 1 nm on sky130hd).
proc gap_moves { tag before } {
  set n 0; set sum 0.0; set big 0; set mx 0.0
  foreach i [[ord::get_db_block] getInsts] {
    set k [$i getName]
    if { ![dict exists $before $k] } { continue }
    lassign [dict get $before $k] x0 y0
    lassign [$i getLocation] x1 y1
    set d [expr { (abs($x1 - $x0) + abs($y1 - $y0)) / 1000.0 }]
    if { $d > 0 } { incr n; set sum [expr { $sum + $d }] }
    if { $d > 5.0 } { incr big }
    if { $d > $mx } { set mx $d }
  }
  puts [format "GAP %-28s cells moved %d, total %.0f um, >5 um: %d, max %.1f um" \
    $tag $n $sum $big $mx]
}

set ::gap_dp 0
proc gap_dp_enter { args } {
  incr ::gap_dp
  set ::gap_pos [gap_snapshot]
  if { $::gap_dp == 2 } { gap_worst_path "after repair, before legalize" }
}
proc gap_dp_leave { args } {
  set tag [expr { $::gap_dp == 1 ? "after CTS legalize" : "after repair legalize" }]
  gap_moves $tag $::gap_pos
  gap_measure $tag
  if { $::gap_dp == 2 } { gap_worst_path "after repair legalize" $::gap_pos }
}
proc gap_rt_enter { args } { gap_measure "before repair_timing" }
proc gap_rt_leave { args } { gap_measure "after repair (not legal)" }

# detailed_placement and repair_timing exist once OpenROAD has started; trace them.
trace add execution detailed_placement enter gap_dp_enter
trace add execution detailed_placement leave gap_dp_leave
trace add execution repair_timing enter gap_rt_enter
trace add execution repair_timing leave gap_rt_leave

source $::env(SCRIPTS_DIR)/cts.tcl
gap_measure "CTS final (should match 4_1_cts.json)"
