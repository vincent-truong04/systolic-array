# eco_upsize_legalize_diodes.tcl: combined ECO on the routed (pre-fill) database:
#   (1) upsize cells to WIDER masters, (2) legalize by a local row shift: the abutting neighbors in
#   the same row are pushed apart (growth split between left and right, the split moving the fewest
#   cells; never past a FIXED cell such as a tap), each by at most the width increase, (3) antenna diodes in the same row as given gate pins (method of eco_antenna_diodes.tcl),
#   (4) rip up the nets of every resized/moved cell and diode net, re-run detailed_route with the
#   ORFS arguments.
# Run via `make ... run RUN_SCRIPT=<this>` in an ECO FLOW_VARIANT that is a copy of the design;
# it overwrites 5_2_route.odb there, then `make ... finish`.
#
# EXP-034-ECO (2026-11-16, Vincent: "Combined ECO and then full signoff"):
# - Setup at ss + max RC: -0.102 (PE(1,7).prod_q[14]), -0.047 (prod_q[15]), launched from PE(0,7).b_out
#   on another gated clock tree (-0.58 ns skew). What-if on the ss_max SPEF (replace_cell, parasitics
#   fixed): the three upsizes below -> worst setup +0.028, ff+min hold unchanged (+0.021).
#   Rows have 0..0.46 um free next to these cells, so same-width swaps are impossible.
#   First try with OpenROAD detailed_placement (negotiation legalizer) moved 98 cells, max 19.5 um:
#   rejected (too much perturbation); replaced by the local row shift.
#   o21bai_4 for _38536_ (combo D, +0.028) does not fit: < 4.14 um free between its two tap cells.
#   Used combo B (all three at size 2): what-if +0.006 at ss+max, ff+min hold +0.021 unchanged.
#   Thin margin, so re-extract and check ss+max right after the ECO, before signoff.
#   _38536_ and _41383_ sit in the last tap segment at the core's right edge (0.92 um free): if no
#   push fits, the resized cell is relocated to the nearest free gap within +-6 rows instead.
# - Magic antenna 3 (OpenROAD 0), mapped from Magic gate rects (x 0.005 um) to the pins below.

set eco_resize {
  _38536_ sky130_fd_sc_hd__o21bai_2
  _38531_ sky130_fd_sc_hd__o21bai_2
  _41383_ sky130_fd_sc_hd__xnor2_2
}
set eco_pins {
  {_45006_ A}
  {_61440_ B}
  {_62339_ GATE}
}
set max_dist 20000   ;# DBU: refuse a diode farther than 20 um from the pin

source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]

set db  [ord::get_db]
set blk [ord::get_db_block]

# ---- (1)+(2) upsize, then local row shift
set moved {}
set touched {}
proc row_cells {inst} {
  set y [[$inst getBBox] yMin]; set l {}
  foreach i [[ord::get_db_block] getInsts] {
    if {$i eq $inst} continue
    set b [$i getBBox]; if {[$b yMin] == $y} { lappend l [list [$b xMin] $i] }
  }
  return [lsort -integer -index 0 $l]
}
# returns list of {inst newx} for pushing right (dir 1) from xmax_new, or left (dir -1) from xmin_new;
# "" if a FIXED cell or the row end blocks it
proc plan_push {inst x0n x1n dir} {
  set cells [row_cells $inst]
  set row ""; set y [[$inst getBBox] yMin]
  foreach r [[ord::get_db_block] getRows] { lassign [$r getOrigin] ox oy; if {$oy == $y} { set row $r } }
  lassign [$row getOrigin] rx0 oy
  set rx1 [expr {$rx0 + [$row getSiteCount]*[[$row getSite] getWidth]}]
  set plan {}
  if {$dir > 0} {
    set edge $x1n
    foreach c $cells { lassign $c cx i
      if {$cx < [[$inst getBBox] xMin]} continue
      if {$cx >= $edge} break
      if {[$i getPlacementStatus] in {FIXED LOCKED FIRM COVER}} { return "" }
      set w [expr {[[$i getBBox] xMax]-$cx}]
      lappend plan [list $i $edge]; set edge [expr {$edge+$w}] }
    if {$edge > $rx1} { return "" }
  } else {
    set edge $x0n
    foreach c [lreverse $cells] { lassign $c cx i
      set cx1 [[$i getBBox] xMax]
      if {$cx1 > [[$inst getBBox] xMax]} continue
      if {$cx1 <= $edge} break
      if {[$i getPlacementStatus] in {FIXED LOCKED FIRM COVER}} { return "" }
      set w [expr {$cx1-$cx}]
      lappend plan [list $i [expr {$edge-$w}]]; set edge [expr {$edge-$w}] }
    if {$edge < $rx0} { return "" }
  }
  return [list $plan]
}
# nearest site-aligned free gap of width w (DBU) within +-nrows rows of inst; {x y orient dist} or ""
proc find_gap {inst w nrows} {
  set blk [ord::get_db_block]
  set ib [$inst getBBox]
  set cx [expr {([$ib xMin]+[$ib xMax])/2}]; set cy [$ib yMin]
  set rh [[[lindex [$blk getRows] 0] getSite] getHeight]
  set best ""; set bd 1e18
  foreach r [$blk getRows] {
    lassign [$r getOrigin] ox oy
    if {abs($oy-$cy) > $nrows*$rh} continue
    set site [[$r getSite] getWidth]
    set rx1 [expr {$ox + [$r getSiteCount]*$site}]
    set iv {}
    foreach i [$blk getInsts] { if {$i eq $inst} continue
      set b [$i getBBox]; if {[$b yMin] <= $oy && [$b yMax] > $oy} { lappend iv [list [$b xMin] [$b xMax]] } }
    set x $ox
    foreach v [concat [lsort -integer -index 0 $iv] [list [list $rx1 $rx1]]] { lassign $v a b
      if {$a - $x >= $w} {
        set c [expr {$cx - $w/2}]
        set c [expr {$ox + int(round(double($c-$ox)/$site))*$site}]
        set lo [expr {$ox + int(ceil(double($x-$ox)/$site))*$site}]
        if {$c < $lo} { set c $lo }; if {$c + $w > $a} { set c [expr {$ox + int(floor(double($a-$w-$ox)/$site))*$site}] }
        if {$c >= $lo} {
          set d [expr {abs($c + $w/2 - $cx) + abs($oy - $cy)}]
          if {$d < $bd} { set bd $d; set best [list $c $oy [$r getOrient] $d] } }
      }
      if {$b > $x} { set x $b } }
  }
  return $best
}
foreach {iname mname} $eco_resize {
  set inst [$blk findInst $iname]
  if {$inst eq "NULL"} { error "ECO: instance $iname not found" }
  set old [$inst getMaster]
  set m [$db findMaster $mname]
  if {$m eq "NULL"} { error "ECO: master $mname not found" }
  lassign [$inst getLocation] x y
  set dw [expr {[$m getWidth]-[$old getWidth]}]
  set site [[[lindex [$blk getRows] 0] getSite] getWidth]
  # split the growth: inst moves left by dl (pushing left neighbors), right edge grows by dw-dl
  # (pushing right neighbors); pick the feasible split that moves the fewest cells
  set best ""; set bn 1e9
  for {set dl 0} {$dl <= $dw} {incr dl $site} {
    set nx0 [expr {$x-$dl}]; set nx1 [expr {$nx0+[$m getWidth]}]
    set pr [plan_push $inst $nx0 $nx1 1]; if {$pr eq ""} continue
    set pl [plan_push $inst $nx0 $nx1 -1]; if {$pl eq ""} continue
    set n [expr {[llength [lindex $pr 0]]+[llength [lindex $pl 0]]}]
    if {$n < $bn} { set bn $n; set best [list $dl [concat [lindex $pr 0] [lindex $pl 0]]] }
  }
  if {$best eq ""} {
    # no room in its own tap segment: move the resized cell to the nearest free gap within
    # +-6 rows (method of eco_resize_drv.tcl); no other cell moves
    set g [find_gap $inst [$m getWidth] 6]
    if {$g eq ""} { error "ECO: no room to push or relocate $iname" }
    lassign $g gx gy orient d
    if {![$inst swapMaster $m]} { error "ECO: swapMaster $iname failed" }
    $inst setOrient $orient
    $inst setLocation $gx $gy
    lappend moved $inst
    puts [format "ECO: %s %s -> %s relocated to (%.2f, %.2f), %.2f um from its old center" $iname [$old getName] $mname [expr {$gx/1000.0}] [expr {$gy/1000.0}] [expr {$d/1000.0}]]
    lappend touched $inst
    continue
  }
  lassign $best dl plan
  if {![$inst swapMaster $m]} { error "ECO: swapMaster $iname failed" }
  $inst setLocation [expr {$x-$dl}] $y
  set side "left [expr {$dl/1000.0}] um / right [expr {($dw-$dl)/1000.0}] um"
  foreach p $plan { lassign $p i nx; lassign [$i getLocation] ox oy
    $i setLocation $nx $oy; lappend moved $i
    puts [format "ECO: shift %s (%s) by %+.2f um" [$i getName] [[$i getMaster] getName] [expr {($nx-$ox)/1000.0}]] }
  puts "ECO: $iname [$old getName] -> $mname (+[expr {$dw/1000.0}] um), pushed [llength $plan] cell(s) $side"
  lappend touched $inst
}
check_placement -verbose

# ---- (3) antenna diodes (same algorithm as eco_antenna_diodes.tcl)
set dio [$db findMaster sky130_fd_sc_hd__diode_2]
set dw  [$dio getWidth]
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
  set gaps {}; set x $ox
  foreach iv [row_busy [expr {$ry + 1}]] {
    lassign $iv a b
    if {$a > $x} { lappend gaps [list $x $a] }
    if {$b > $x} { set x $b }
  }
  if {$x < $rx1} { lappend gaps [list $x $rx1] }
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
  set dname ANTENNA_ECO034_[incr k]
  set d [odb::dbInst_create $blk $dio $dname]
  $d setOrient [$row getOrient]
  $d setLocation $best $ry
  $d setPlacementStatus PLACED
  [$d findITerm DIODE] connect $net
  puts [format "ECO: %s at (%.2f, %.2f) on %s for %s/%s, %.2f um from the pin" $dname [expr {$best/1000.0}] [expr {$ry/1000.0}] [$net getName] $iname $pname [expr {$bd/1000.0}]]
  if {[lsearch $nets $net] < 0} { lappend nets $net }
}
puts "ECO antenna before (OpenROAD):"
foreach n $nets { check_antennas -net [$n getName] -verbose }

# ---- (4) rip up and reroute
foreach i [concat $touched $moved] {
  foreach it [$i getITerms] {
    set n [$it getNet]
    if {$n ne "NULL" && [$n getSigType] eq "SIGNAL" && [lsearch $nets $n] < 0} { lappend nets $n }
  }
}
set nrip 0
foreach n $nets {
  set w [$n getWire]
  if { $w ne "NULL" } { odb::dbWire_destroy $w; incr nrip }
}
puts "ECO: ripped up $nrip nets"

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
set all_args [concat [list -output_drc $::env(REPORTS_DIR)/5_route_drc_eco034.rpt \
  -output_maze $::env(RESULTS_DIR)/maze_eco034.log] $additional_args {-drc_report_iter_step 5}]
log_cmd detailed_route {*}$all_args

if { ![design_is_routed] } { error "ECO: design has unrouted nets" }
puts "ECO antenna after (OpenROAD):"
foreach n [lrange $nets 0 2] { check_antennas -net [$n getName] -verbose }
check_antennas -report_file $::env(REPORTS_DIR)/drt_antennas_eco034.log
orfs_write_db $::env(RESULTS_DIR)/5_2_route.odb
puts "ECO: wrote 5_2_route.odb"
