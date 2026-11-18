# export_insts.tcl: dump placed instances (name, master, bbox in DBU) of the final layout for pe_placement.py.
# Usage (repo root): OUT=insts.tsv openroad -exit -no_splash docs/scripts/export_insts.tcl
read_db build/orfs/results/sky130hd/systolic_8x8/clk10_u70_lanes_cg_gd_holdeco/6_final.odb
set f [open $::env(OUT) w]
set blk [ord::get_db_block]
set die [$blk getDieArea]
puts $f "#die [$die xMax] [$die yMax]"
foreach i [$blk getInsts] {
  set m [$i getMaster]
  if {[$m getType] ne "CORE" } { if {![string match "CORE*" [$m getType]]} continue }
  set mn [$m getName]
  if {[string match *fill* $mn] || [string match *tapvpwr* $mn] || [string match *decap* $mn]} continue
  set b [$i getBBox]
  puts $f "[$i getName]\t$mn\t[$b xMin]\t[$b yMin]\t[$b xMax]\t[$b yMax]"
}
close $f
