# Post-route STA with OpenROAD's own RC extraction at ONE RC corner + ONE library corner.
# Unlike corner_sta.tcl (reads ORFS's nominal 6_final.spef), this re-extracts parasitics
# from 6_final.odb with a given OpenRCX rules file (e.g. open_pdks
# libs.tech/openlane/rules.openrcx.sky130A.{min,nom,max}.calibre), writes the SPEF, then
# reports timing and DRV. Same extraction commands as ORFS final_outputs.tcl.
# Env: RES=<ORFS results dir>  LIB=<liberty>  RCX=<OpenRCX rules file>  SPEF=<output .spef>
read_liberty $::env(LIB)
read_db  $::env(RES)/6_final.odb
read_sdc $::env(RES)/6_final.sdc
define_process_corner -ext_model_index 0 X
set_extraction_rules_file $::env(RCX)
extract_parasitics
write_spef $::env(SPEF)
read_spef  $::env(SPEF)
puts "=== LIB [file tail $::env(LIB)]  RCX [file tail $::env(RCX)]"
report_worst_slack -max -digits 3
report_tns -max -digits 3
report_worst_slack -min -digits 3
report_tns -min -digits 3
puts "max_slew violations:        [sta::max_slew_violation_count]"
puts "max_capacitance violations: [sta::max_capacitance_violation_count]"
puts "max_fanout violations:      [sta::max_fanout_violation_count]"
puts "=== worst setup endpoints"
report_checks -path_delay max -format end -group_path_count 5
puts "=== worst hold endpoints"
report_checks -path_delay min -format end -group_path_count 5
puts "=== worst setup path"
report_checks -path_delay max -fields {fanout cap slew} -digits 3
puts "=== DRV violators"
report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 3
