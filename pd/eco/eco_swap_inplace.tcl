# eco_swap_inplace.tcl: same-footprint cell swap ECO on the routed (pre-fill) database.
# Swaps one instance to another size with the SAME width (no placement change), rips up the
# signal nets on its pins (pin shapes can differ between sizes) and re-runs detailed_route
# with the ORFS arguments. Same method/flow as eco_resize_drv.tcl.
# Run via `make ... run RUN_SCRIPT=<this>` in an ECO FLOW_VARIANT that is a copy of the
# design to change; it overwrites 5_2_route.odb there, then `make ... finish`.
#
# EXP-025-ECO2 (2026-11-13): EXP-025-ECO fails setup at ss + max RC by 0.052 ns on
# PE(1,7).prod_q[15]. The path's weakest stage is _47600_ sky130_fd_sc_hd__o21ai_0
# (slew 0.425 at ss+max). What-if on the ss+max SPEF (replace_cell, parasitics fixed):
# o21ai_1 (same 1.84 um width) -> that endpoint +0.137, hold at ff+min unchanged (+0.093).
# o21ai_2 (+0.166) is 1.38 um wider with 0 free space; buf/flop upsizes gave only +0.011.

set eco_inst   _47600_
set eco_master sky130_fd_sc_hd__o21ai_1

source $::env(SCRIPTS_DIR)/load.tcl
load_design 5_2_route.odb 5_1_grt.sdc
set_propagated_clock [all_clocks]

set db  [ord::get_db]
set blk [ord::get_db_block]
set inst [$blk findInst $eco_inst]
if { $inst eq "NULL" } { error "ECO: instance $eco_inst not found" }
set old [$inst getMaster]
set new [$db findMaster $eco_master]
if { [$old getWidth] != [$new getWidth] || [$old getHeight] != [$new getHeight] } {
  error "ECO: [$old getName] and $eco_master differ in size; use eco_resize_drv.tcl"
}
set loc [$inst getLocation]

set nets {}
foreach it [$inst getITerms] {
  set n [$it getNet]
  if { $n ne "NULL" && [$n getSigType] eq "SIGNAL" } { lappend nets $n }
}

$inst swapMaster $new
if { [$inst getLocation] ne $loc } { error "ECO: location changed after swapMaster" }
puts "ECO: $eco_inst [$old getName] -> $eco_master at ([expr {[lindex $loc 0]/1000.0}], [expr {[lindex $loc 1]/1000.0}]), in place"

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
set all_args [concat [list -output_drc $::env(REPORTS_DIR)/5_route_drc_eco2.rpt \
  -output_maze $::env(RESULTS_DIR)/maze_eco2.log] $additional_args {-drc_report_iter_step 5}]
log_cmd detailed_route {*}$all_args

if { ![design_is_routed] } { error "ECO: design has unrouted nets" }
check_antennas -report_file $::env(REPORTS_DIR)/drt_antennas_eco2.log
orfs_write_db $::env(RESULTS_DIR)/5_2_route.odb
puts "ECO: wrote 5_2_route.odb"
