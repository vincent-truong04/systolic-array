# io_dataflow_lanes.tcl: dataflow pin placement with one region per array lane (EXP-024).
# Replaces pd/io_dataflow.tcl, whose single `-region top:* -group` packed all 64 b_row pins
# into x 8-66 um at the top-left corner (EXP-023 signoff: 13 max-slew + 6 max-cap at ss on
# b_row input buffers driving 300-430 um nets).
#
# Sourced by ORFS floorplan.tcl via IO_CONSTRAINTS after the die/core exist, so the lanes
# follow the actual floorplan. The core is split into N equal lanes per edge:
#   b_row  column j (bits [j*8 +: 8])   -> top edge,    x lane j (left to right)
#   a_col  row i    (bits [i*8 +: 8])   -> left edge,   y lane i (row 0 at the TOP, where b enters)
#   out_data column j (bits [j*32 +: 32]) -> bottom edge, x lane j
# Each lane keeps its bits together and in order (-group -order) inside its own region.
# clk, rst, in_valid/first/last/ready, out_row, out_valid: no constraint (tool's choice, as EXP-014).

set DATA_W 8
set ACC_W  32
set blk  [ord::get_db_block]
set dbu  [[ord::get_db_tech] getDbUnitsPerMicron]
set core [$blk getCoreArea]
set cx0 [expr { double([$core xMin]) / $dbu }]
set cx1 [expr { double([$core xMax]) / $dbu }]
set cy0 [expr { double([$core yMin]) / $dbu }]
set cy1 [expr { double([$core yMax]) / $dbu }]
set N   [expr { [llength [lsearch -all -glob [lmap b [$blk getBTerms] {$b getName}] {b_row\[*}]] / $DATA_W }]
set lw  [expr { ($cx1 - $cx0) / $N }]
set lh  [expr { ($cy1 - $cy0) / $N }]

proc lane_bits { bus base w } {
  set l {}
  for { set k 0 } { $k < $w } { incr k } { lappend l "${bus}\[[expr { $base + $k }]\]" }
  return $l
}

for { set j 0 } { $j < $N } { incr j } {
  set x0 [format %.2f [expr { $cx0 + $j * $lw }]]
  set x1 [format %.2f [expr { $cx0 + ($j + 1) * $lw }]]
  set_io_pin_constraint -pin_names [lane_bits b_row [expr { $j * $DATA_W }] $DATA_W] \
    -region top:$x0-$x1 -group -order
  set_io_pin_constraint -pin_names [lane_bits out_data [expr { $j * $ACC_W }] $ACC_W] \
    -region bottom:$x0-$x1 -group -order
}
for { set i 0 } { $i < $N } { incr i } {
  set y1 [format %.2f [expr { $cy1 - $i * $lh }]]
  set y0 [format %.2f [expr { $cy1 - ($i + 1) * $lh }]]
  set_io_pin_constraint -pin_names [lane_bits a_col [expr { $i * $DATA_W }] $DATA_W] \
    -region left:$y0-$y1 -group -order
}
puts [format "IO_LANES: N=%d core x %.2f..%.2f y %.2f..%.2f lane %.2f x %.2f um" \
  $N $cx0 $cx1 $cy0 $cy1 $lw $lh]
