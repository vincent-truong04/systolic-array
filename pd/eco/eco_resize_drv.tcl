# eco_resize_drv.tcl: one-cell resize ECO on the routed (pre-fill) database.
# Swaps one instance to a stronger cell with the same pins, places it in free row space,
# rips up the nets on its pins and re-runs detailed_route with the ORFS arguments
# (same method as eco_antenna_diode.tcl). Leaves every other cell where it is.
# Run via `make ... run RUN_SCRIPT=<this>` in an ECO FLOW_VARIANT that is a copy of the
# original results; it overwrites 5_2_route.odb there, then `make ... finish` redoes fill,
# reports and GDS.
#
# EXP-025 (2026-11-13): net _31237_ driven by _67142_ sky130_fd_sc_hd__o41ai_1 at
# (77.28, 590.24), 3 sinks up to ~42 um away: max slew 1.548 > 1.495/1.500 ns (4 pins),
# max cap 0.020 > 0.018 pF (ss_100C_1v60). o41ai_2 is 5.98 um wide vs 3.22; the row is free
# from the tap cell (x 70.84) to x 77.28, so the new cell goes at x 74.52 (site-aligned,
# 162 * 0.46) and ends at 80.50, the left edge of the next cell. No other cell moves.

set eco_inst   _67142_
set eco_master sky130_fd_sc_hd__o41ai_2
set eco_x      74520   ;# DBU (nm)

source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]

set db  [ord::get_db]
set blk [ord::get_db_block]
set inst [$blk findInst $eco_inst]
if { $inst eq "NULL" } { error "ECO: instance $eco_inst not found" }
set new [$db findMaster $eco_master]
set y   [[$inst getBBox] yMin]
set x1  [expr { $eco_x + [$new getWidth] }]

# The new footprint may overlap only the instance itself.
foreach i [$blk getInsts] {
  if { $i eq $inst } { continue }
  set b [$i getBBox]
  if { [$b yMin] == $y && [$b xMin] < $x1 && [$b xMax] > $eco_x } {
    error "ECO: footprint x $eco_x..$x1 overlaps [$i getName]"
  }
}

puts "ECO before: [[$inst getMaster] getName] at ([expr {[[$inst getBBox] xMin]/1000.0}], [expr {$y/1000.0}])"
estimate_parasitics -global_routing
report_check_types -max_slew -max_capacitance -violators -digits 3

set nets {}
foreach it [$inst getITerms] {
  set n [$it getNet]
  if { $n ne "NULL" && [$n getSigType] eq "SIGNAL" } { lappend nets $n }
}

$inst swapMaster $new
$inst setLocation $eco_x $y
$inst setPlacementStatus PLACED
puts "ECO: $eco_inst -> $eco_master at ([expr {$eco_x/1000.0}], [expr {$y/1000.0}])"

# Pin shapes moved: rip up every signal net on the instance so the router reconnects them.
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
set all_args [concat [list -output_drc $::env(REPORTS_DIR)/5_route_drc_eco.rpt \
  -output_maze $::env(RESULTS_DIR)/maze_eco.log] $additional_args {-drc_report_iter_step 5}]
log_cmd detailed_route {*}$all_args

if { ![design_is_routed] } { error "ECO: design has unrouted nets" }
check_antennas -report_file $::env(REPORTS_DIR)/drt_antennas_eco.log
puts "ECO after (routed wire RC, flow corner):"
estimate_parasitics -placement
report_check_types -max_slew -max_capacitance -violators -digits 3
orfs_write_db $::env(RESULTS_DIR)/5_2_route.odb
puts "ECO: wrote 5_2_route.odb"
