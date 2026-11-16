# eco_antenna_diodes.tcl: multi-net antenna diode ECO on the routed (pre-fill) database.
# For each {instance pin}: place one sky130_fd_sc_hd__diode_2 in the nearest free site gap of the
# SAME row as the gate's cell (EXP-023 lesson: from another row the router must hop over the met1
# rail on met2, and the diode no longer protects the met1/lower pieces), connect its DIODE pin to
# the pin's net, rip up those nets, and re-run detailed_route with the ORFS arguments.
# Run via `make ... run RUN_SCRIPT=<this>` in an ECO FLOW_VARIANT that is a copy of the design;
# it overwrites 5_2_route.odb there, then `make ... finish`.
#
# EXP-025-ECO3 (2026-11-15): Magic `antennacheck` on EXP-025-ECO2 flags 5 gates on met4
# (effective ratio 420..1355 > 400) that OpenROAD check_antennas passes. The pins were mapped with
# `check_antennas -net -verbose`: each is a met4 partial with no diffusion credit (required 400).

set eco_pins {
  {_68763_ B1}
  {{u_array.g_row\[4\].g_col\[1\].u_pe.a_out\[2\]$_DFF_P_} D}
  {_54812_ A}
  {_68879_ A1}
  {_57796_ B1}
}
set max_dist 20000 ;# DBU: refuse a diode farther than 20 um from the pin

source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]

set db  [ord::get_db]
set blk [ord::get_db_block]
set dio [$db findMaster sky130_fd_sc_hd__diode_2]
set dw  [$dio getWidth]

# Occupied x-intervals per row y (all placed instances, incl. taps and earlier ECO diodes).
proc row_busy {y} {
  set iv {}
  foreach i [[ord::get_db_block] getInsts] {
    set b [$i getBBox]
    if {[$b yMin] <= $y && [$b yMax] > $y} { lappend iv [list [$b xMin] [$b xMax]] }
  }
  return [lsort -integer -index 0 $iv]
}

set nets {}
set k 0
foreach p $eco_pins {
  lassign $p iname pname
  set inst [$blk findInst $iname]
  if {$inst eq "NULL"} { error "ECO: instance $iname not found" }
  set it [$inst findITerm $pname]
  set net [$it getNet]
  set pb [$it getBBox]; set px [expr {([$pb xMin]+[$pb xMax])/2}]
  set ry [[$inst getBBox] yMin]
  set row ""
  foreach r [$blk getRows] { lassign [$r getOrigin] ox oy; if {$oy == $ry} { set row $r; break } }
  if {$row eq ""} { error "ECO: no row at y=$ry for $iname" }
  lassign [$row getOrigin] ox oy
  set site [[$row getSite] getWidth]
  set rx1 [expr {$ox + [$row getSiteCount]*$site}]
  # free gaps in this row
  set gaps {}; set x $ox
  foreach iv [row_busy [expr {$ry + 1}]] {
    lassign $iv a b
    if {$a > $x} { lappend gaps [list $x $a] }
    if {$b > $x} { set x $b }
  }
  if {$x < $rx1} { lappend gaps [list $x $rx1] }
  # best site-aligned diode position: closest to the pin
  set best ""; set bd 1e18
  foreach g $gaps {
    lassign $g a b
    set a [expr {$ox + int(ceil(double($a-$ox)/$site))*$site}]
    if {$b - $a < $dw} continue
    set c [expr {$px - $dw/2}]
    set c [expr {$ox + int(round(double($c-$ox)/$site))*$site}]
    if {$c < $a} { set c $a }; if {$c + $dw > $b} { set c [expr {$b - $dw}] }
    set d [expr {abs($c + $dw/2 - $px)}]
    if {$d < $bd} { set bd $d; set best $c }
  }
  if {$best eq "" || $bd > $max_dist} { error "ECO: no free gap within [expr {$max_dist/1000.0}] um of $iname/$pname" }
  set dname ANTENNA_ECO3_[incr k]
  set d [odb::dbInst_create $blk $dio $dname]
  $d setOrient [$row getOrient]
  $d setLocation $best $ry
  $d setPlacementStatus PLACED
  [$d findITerm DIODE] connect $net
  puts [format "ECO: %s at (%.2f, %.2f) on %s for %s/%s, %.2f um from the pin" $dname [expr {$best/1000.0}] [expr {$ry/1000.0}] [$net getName] $iname $pname [expr {$bd/1000.0}]]
  if {[lsearch $nets $net] < 0} { lappend nets $net }
}

puts "ECO before (OpenROAD):"
foreach n $nets { check_antennas -net [$n getName] }
foreach n $nets {
  set w [$n getWire]
  if { $w ne "NULL" } { odb::dbWire_destroy $w; puts "ECO: ripped up [$n getName]" }
}

# Same detailed_route arguments as ORFS detail_route.tcl.
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
set all_args [concat [list -output_drc $::env(REPORTS_DIR)/5_route_drc_eco3.rpt \
  -output_maze $::env(RESULTS_DIR)/maze_eco3.log] $additional_args {-drc_report_iter_step 5}]
log_cmd detailed_route {*}$all_args

if { ![design_is_routed] } { error "ECO: design has unrouted nets" }
puts "ECO after (OpenROAD):"
foreach n $nets { check_antennas -net [$n getName] }
check_antennas -report_file $::env(REPORTS_DIR)/drt_antennas_eco3.log
orfs_write_db $::env(RESULTS_DIR)/5_2_route.odb
puts "ECO: wrote 5_2_route.odb"
