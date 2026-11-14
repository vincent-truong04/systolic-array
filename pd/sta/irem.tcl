# Static IR drop + EM on VDD/VSS of a finished ORFS run at ONE library corner.
# Env: RES, LIB, VDD (supply voltage of that corner), SRC (FULL|STRAPS|BUMPS), OUT (prefix)
read_liberty $::env(LIB)
read_db   $::env(RES)/6_final.odb
read_sdc  $::env(RES)/6_final.sdc
read_spef $::env(RES)/6_final.spef
puts "=== LIB [file tail $::env(LIB)]  VDD=$::env(VDD)  source_type=$::env(SRC)"
# Optional (added 2026-11-14): switching activity from a gate-level VCD instead of the
# default (vectorless) activity. Env: VCD=<file.vcd>  VCD_SCOPE=<instance path of the top>
if { [info exists ::env(VCD)] && $::env(VCD) ne "" } {
  set_propagated_clock [all_clocks]
  read_vcd -scope $::env(VCD_SCOPE) $::env(VCD)
  report_activity_annotation
}
report_power -digits 4
# Optional (added 2026-11-14): explicit voltage-source locations (-vsrc CSV: x,y,edge,V).
# Needed to model anything but ideal supply: this design exports every met5 strap as a
# block pin, and PDNSim uses block pins as sources whenever they exist, ignoring
# -source_type (ir_solver.cpp generateSourceNodes). Env: VSRC_VDD, VSRC_VSS.
set vsrc_vdd {}; set vsrc_vss {}
if { [info exists ::env(VSRC_VDD)] && $::env(VSRC_VDD) ne "" } { set vsrc_vdd [list -vsrc $::env(VSRC_VDD)] }
if { [info exists ::env(VSRC_VSS)] && $::env(VSRC_VSS) ne "" } { set vsrc_vss [list -vsrc $::env(VSRC_VSS)] }
set_pdnsim_net_voltage -net VDD -voltage $::env(VDD)
set_pdnsim_net_voltage -net VSS -voltage 0.0
analyze_power_grid -net VDD -source_type $::env(SRC) {*}$vsrc_vdd -enable_em -em_outfile $::env(OUT)_VDD_em.rpt -voltage_file $::env(OUT)_VDD_v.rpt -error_file $::env(OUT)_VDD_err.rpt
analyze_power_grid -net VSS -source_type $::env(SRC) {*}$vsrc_vss -enable_em -em_outfile $::env(OUT)_VSS_em.rpt -error_file $::env(OUT)_VSS_err.rpt
