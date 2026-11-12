# Magic DRC (sky130A full rule deck) on a final GDS, batch mode.
# Run: magic -dnull -noconsole -rcfile $PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc pd/signoff/magic_drc.tcl
# Env: GDS=<gds path>  TOP=<top cell>  OUT=<report prefix>
set gds $::env(GDS); set top $::env(TOP); set out $::env(OUT)
puts "magic_drc: reading $gds"
gds readonly true
gds read $gds
load $top
select top cell
drc euclidean on
drc style drc(full)
set t0 [clock seconds]
drc check
drc catchup
set n [drc list count total]
puts "MAGIC_DRC_COUNT $n  ([expr {[clock seconds]-$t0}] s)"
set fp [open $out.rpt w]
puts $fp "top $top  gds $gds"
puts $fp "total DRC error tiles: $n"
foreach {why boxes} [drc listall why] {
    puts $fp "$why  ([llength $boxes] boxes)"
    foreach b [lrange $boxes 0 9] { puts $fp "    $b" }
}
close $fp
quit -noprompt
