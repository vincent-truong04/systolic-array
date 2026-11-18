# io_sram.tcl (IO_CONSTRAINTS, EXP-035 DRAFT): pin placement for systolic_sram_top.
# Same lane idea as io_dataflow_lanes.tcl (EXP-024), but b_row is gone (B comes from the macro) and
# the array only occupies the core below the macro, so the lanes are computed over that region:
#   a_col    row i    -> left edge,   lane i of the region below the macro (row 0 at the top)
#   out_data column j -> bottom edge, lane j
#   wr_data          -> top edge, over the macro's din0 pins (x 154..616 um in the macro, MX keeps x)
#   wr_addr, wr_en   -> top edge, over the macro's left part (addr0/csb0 are on its left side)
#   in_valid/first/last/ready, b_base -> left edge above lane 0 (they feed the s1 regs next to a_col)
# clk, rst, out_valid, out_row: unconstrained (tool's choice, as before).
# Sourced at floorplan (before macro placement), so the macro position comes from the config env.

set DATA_W 8
set ACC_W  32
set blk  [ord::get_db_block]
set dbu  [[ord::get_db_tech] getDbUnitsPerMicron]
set core [$blk getCoreArea]
set cx0 [expr { double([$core xMin]) / $dbu }]
set cx1 [expr { double([$core xMax]) / $dbu }]
set cy0 [expr { double([$core yMin]) / $dbu }]
set cy1 [expr { double([$core yMax]) / $dbu }]
set mx  $::env(SRAM_X)
set ylo [expr { $::env(SRAM_Y) - $::env(SRAM_HALO) }]   ;# top of the stdcell region
set N   [expr { [llength [lsearch -all -glob [lmap b [$blk getBTerms] {$b getName}] {a_col\[*}]] / $DATA_W }]
set lw  [expr { ($cx1 - $cx0) / $N }]
set lh  [expr { ($ylo - 40.0 - $cy0) / $N }]            ;# keep 40 um above lane 0 for control pins

proc bits { bus base w } {
  set l {}
  for { set k 0 } { $k < $w } { incr k } { lappend l "${bus}\[[expr { $base + $k }]\]" }
  return $l
}

for { set j 0 } { $j < $N } { incr j } {
  set x0 [format %.2f [expr { $cx0 + $j * $lw }]]
  set x1 [format %.2f [expr { $cx0 + ($j + 1) * $lw }]]
  set_io_pin_constraint -pin_names [bits out_data [expr { $j * $ACC_W }] $ACC_W] \
    -region bottom:$x0-$x1 -group -order
}
for { set i 0 } { $i < $N } { incr i } {
  set y1 [format %.2f [expr { $ylo - 40.0 - $i * $lh }]]
  set y0 [format %.2f [expr { $ylo - 40.0 - ($i + 1) * $lh }]]
  set_io_pin_constraint -pin_names [bits a_col [expr { $i * $DATA_W }] $DATA_W] \
    -region left:$y0-$y1 -group -order
}
set_io_pin_constraint -pin_names [concat {in_valid in_ready in_first in_last} [bits b_base 0 6]] \
  -region left:[format %.2f [expr { $ylo - 40.0 }]]-[format %.2f $ylo]
set_io_pin_constraint -pin_names [bits wr_data 0 [expr { $N * $DATA_W }]] \
  -region top:[format %.2f [expr { $mx + 154.0 }]]-[format %.2f [expr { $mx + 616.0 }]] -group -order
set_io_pin_constraint -pin_names [concat wr_en [bits wr_addr 0 6]] \
  -region top:[format %.2f [expr { $mx + 20.0 }]]-[format %.2f [expr { $mx + 140.0 }]]
puts [format "IO_SRAM: N=%d core x %.2f..%.2f y %.2f..%.2f, array region y < %.2f, lane %.2f x %.2f um" \
  $N $cx0 $cx1 $cy0 $cy1 $ylo $lw $lh]
