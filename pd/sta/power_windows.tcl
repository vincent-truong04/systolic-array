# Power of a finished ORFS run from a gate-level VCD, measured over time windows
# (one per workload), at ONE library corner with the run's SPEF.
# Env: RES=<ORFS results dir>  LIB=<liberty>  VCD=<file.vcd>  SCOPE=<VCD scope of the top>
#      WINDOWS="name begin end;name begin end;..." (raw VCD time units, e.g. ps)
#      OUT=<output dir>  -> <name>.rpt (report_power + annotation) and <name>_inst.json
#                           (report_power -instances [all cells] -format json)
read_liberty $::env(LIB)
read_db   $::env(RES)/6_final.odb
read_sdc  $::env(RES)/6_final.sdc
read_spef $::env(RES)/6_final.spef
set_propagated_clock [all_clocks]
puts "=== LIB [file tail $::env(LIB)]  VCD [file tail $::env(VCD)]"
set cells [get_cells *]
foreach w [split $::env(WINDOWS) ";"] {
  lassign $w name t0 t1
  if { $name eq "" } { continue }
  set t [clock milliseconds]
  read_vcd -scope $::env(SCOPE) -begin_time $t0 -end_time $t1 $::env(VCD)
  set f $::env(OUT)/$name.rpt
  set fh [open $f w]; puts $fh "=== window $name: $t0 .. $t1 (VCD units)"; close $fh
  report_activity_annotation >> $f
  report_power -digits 6 >> $f
  report_power -instances $cells -digits 6 -format json > $::env(OUT)/${name}_inst.json
  puts "window $name ($t0..$t1): [expr {([clock milliseconds]-$t)/1000.0}] s"
}
