# eco_antenna_diode.tcl: one-net antenna ECO on the routed (pre-fill) database.
# Places one sky130_fd_sc_hd__diode_2 at a given free site, connects its DIODE pin to the
# net, and re-runs detailed_route with the ORFS arguments; like the ORFS post-route antenna
# loop, the router only completes the new connection on an already-routed design.
# Run via `make ... run RUN_SCRIPT=<this>` in an ECO FLOW_VARIANT that is a copy of the
# original results; it overwrites 5_2_route.odb there, then `make ... finish` redoes fill,
# reports and GDS.
#
# EXP-023 (2026-11-12): net u_array.a_h[57][7], met1 side-area 471.6 > 400 at place1612/A.
# ~101 um met1 trunk reaches the pin with no diffusion; the 10 repair diodes sit beyond a
# met3 hop. Free gap found at row y=122.40, x 230.00..235.98 (directly above place1612/A).

set eco_net  {u_array.a_h\[57\]\[7\]}
# The diode must sit in the SAME row as the met1 trunk (row y=119.68): from the row above
# (first try: x 234.14, y 122.40) the router has to cross the met1 power rail on met2, so
# the diode joins only at met2 and does not protect the met1 piece (ratio 471.6 -> 461.1).
# Row 119.68 is full near place1612; free gap x 195.04..212.98 lies under the trunk (y 120.87).
set eco_x    211600   ;# DBU (nm), site-aligned (195.04 + 36*0.46), under the met1 trunk
set eco_y    119680   ;# row origin y (same row as place1612 and the trunk)
set eco_name ANTENNA_ECO_1

source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]

set blk [ord::get_db_block]
set net [$blk findNet $eco_net]
if { $net eq "NULL" } { error "ECO: net $eco_net not found" }

puts "ECO before:"
check_antennas -net [$net getName]

# Row orientation at eco_y, and a check that the 0.92 um footprint is still empty.
set master [[ord::get_db] findMaster sky130_fd_sc_hd__diode_2]
set orient ""
foreach row [$blk getRows] {
  lassign [$row getOrigin] rx ry
  if { $ry == $eco_y } { set orient [$row getOrient]; break }
}
if { $orient eq "" } { error "ECO: no row at y=$eco_y" }
set x1 [expr { $eco_x + [$master getWidth] }]
foreach i [$blk getInsts] {
  set bb [$i getBBox]
  if { [$bb yMin] == $eco_y && [$bb xMin] < $x1 && [$bb xMax] > $eco_x } {
    error "ECO: site occupied by [$i getName]"
  }
}

set inst [odb::dbInst_create $blk $master $eco_name]
$inst setOrient $orient
$inst setLocation $eco_x $eco_y
$inst setPlacementStatus PLACED
[$inst findITerm DIODE] connect $net
puts "ECO: placed $eco_name ($orient) at ([expr {$eco_x/1000.0}], [expr {$eco_y/1000.0}]) on [$net getName]"

# detailed_route leaves nets that already have wiring alone (first ECO attempt: the diode
# stayed unconnected). Rip up this one net so it is rerouted inside its existing guides
# (li1/met1 guides already cover x 227.7..234.6, y 117.3..124.2, next to the diode).
set w [$net getWire]
if { $w ne "NULL" } { odb::dbWire_destroy $w; puts "ECO: ripped up wiring of [$net getName]" }

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

puts "ECO after:"
check_antennas -net [$net getName]
check_antennas -report_file $::env(REPORTS_DIR)/drt_antennas_eco.log
if { ![design_is_routed] } { error "ECO: design has unrouted nets" }
orfs_write_db $::env(RESULTS_DIR)/5_2_route.odb
puts "ECO: wrote 5_2_route.odb"
