# Magic DRC (sky130A full rule deck) on a final GDS, batch mode.
# Run: magic -dnull -noconsole -rcfile $PDK_ROOT/sky130A/libs.tech/magic/sky130A.magicrc pd/signoff/magic_drc.tcl
# Env: GDS=<gds path>  TOP=<top cell>  OUT=<report prefix>
# Notes (2026-11-12): Magic shadows Tcl's `clock`, so timing uses `exec date`.
# `drc count total` prints but returns nothing in -dnull mode; `drc listall why` returned nothing,
# so errors are listed with a `drc find` loop (each call moves the box to the next error).
set gds $::env(GDS); set top $::env(TOP); set out $::env(OUT)
puts "magic_drc: reading $gds"
gds readonly true
gds read $gds
load $top
select top cell
puts "BBOX [box values]"
drc euclidean on
drc style drc(full)
set t0 [exec date +%s]
drc check
drc catchup
puts "MAGIC_DRC_SECONDS [expr {[exec date +%s]-$t0}]"
drc count total
set counts [drc listall count]
set n 0
foreach pair $counts { if {[lindex $pair 0] eq $top} { set n [lindex $pair 1] } }
puts "MAGIC_DRC_COUNT $n"
set fp [open $out.rpt w]
puts $fp "top $top  gds $gds"
puts $fp "error count in $top (drc listall count): $n"
puts $fp "per-cell counts: $counts"
# Each find moves the box to the next error; print location (internal units, 0.005 um) and reason.
for {set i 0} {$i < $n} {incr i} {
    set why [drc find]
    puts $fp "[box values]"
}
close $fp
quit -noprompt
