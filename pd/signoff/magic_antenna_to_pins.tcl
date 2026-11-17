# magic_antenna_to_pins.tcl: map Magic `antennacheck` violations to OpenROAD {instance pin} pairs.
# Magic reports the flattened cell as <master>_<n> and the gate rectangle in Magic internal units
# (0.005 um with the sky130A magicrc, checked on EXP-034: every hit lands on a cell of the reported
# master within 2 um). For each violation: the nearest instance of that master to the gate rect
# center, then its nearest INPUT pin. Output: one "{inst} pin" line per violation (input format of
# eco_antenna_diodes.tcl's ANTENNA_PINS file).
# Env: ODB=<routed .odb>  LOG=<antenna_magic.log>  OUT=<pins file>
read_db $::env(ODB)
set blk [ord::get_db_block]
set fh [open $::env(LOG)]; set txt [read $fh]; close $fh
set out [open $::env(OUT) w]
set n 0
foreach {- master x0 y0 x1 y1} [regexp -all -inline {Cell: sky130_fd_sc_hd__(\w+?)_\d+\s+Antenna violation detected[^\n]*\n[^\n]*\nGate rect \((-?\d+) (-?\d+)\) to \((-?\d+) (-?\d+)\)} $txt] {
  set cx [expr {int(($x0+$x1)/2.0*5)}]; set cy [expr {int(($y0+$y1)/2.0*5)}]
  set bi ""; set bd 1e18
  foreach i [$blk getInsts] {
    if {[[$i getMaster] getName] ne "sky130_fd_sc_hd__$master"} continue
    set b [$i getBBox]
    set d [expr {abs(([$b xMin]+[$b xMax])/2-$cx)+abs(([$b yMin]+[$b yMax])/2-$cy)}]
    if {$d < $bd} { set bd $d; set bi $i }
  }
  if {$bi eq ""} { error "no instance of $master" }
  set bp ""; set pd 1e18
  foreach it [$bi getITerms] {
    if {[[$it getMTerm] getIoType] ne "INPUT" || [$it getNet] eq "NULL"} continue
    if {[[$it getNet] getSigType] ne "SIGNAL"} continue
    set pb [$it getBBox]
    set d [expr {abs(([$pb xMin]+[$pb xMax])/2-$cx)+abs(([$pb yMin]+[$pb yMax])/2-$cy)}]
    if {$d < $pd} { set pd $d; set bp $it }
  }
  set pin [[$bp getMTerm] getName]
  puts [format "MAP %s gate (%.2f, %.2f) -> %s (cell %.2f um) pin %s net %s (pin %.2f um)" $master \
        [expr {$cx/1000.0}] [expr {$cy/1000.0}] [$bi getName] [expr {$bd/1000.0}] $pin [[$bp getNet] getName] [expr {$pd/1000.0}]]
  puts $out "{[$bi getName]} $pin"
  incr n
}
close $out
puts "mapped $n violations -> $::env(OUT)"
