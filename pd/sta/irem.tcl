# Static IR drop + EM on VDD/VSS of a finished ORFS run at ONE library corner.
# Env: RES, LIB, VDD (supply voltage of that corner), SRC (FULL|STRAPS|BUMPS), OUT (prefix)
read_liberty $::env(LIB)
read_db   $::env(RES)/6_final.odb
read_sdc  $::env(RES)/6_final.sdc
read_spef $::env(RES)/6_final.spef
puts "=== LIB [file tail $::env(LIB)]  VDD=$::env(VDD)  source_type=$::env(SRC)"
report_power -digits 4
set_pdnsim_net_voltage -net VDD -voltage $::env(VDD)
set_pdnsim_net_voltage -net VSS -voltage 0.0
analyze_power_grid -net VDD -source_type $::env(SRC) -enable_em -em_outfile $::env(OUT)_VDD_em.rpt -voltage_file $::env(OUT)_VDD_v.rpt -error_file $::env(OUT)_VDD_err.rpt
analyze_power_grid -net VSS -source_type $::env(SRC) -enable_em -em_outfile $::env(OUT)_VSS_em.rpt -error_file $::env(OUT)_VSS_err.rpt
