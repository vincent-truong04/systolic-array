# Post-route STA of a finished ORFS run at ONE library corner.
# Env: RES=<ORFS results dir>  LIB=<liberty file>
# The SPEF is ORFS's nominal-RC extraction; only the cell library changes per corner.
set res $::env(RES)
read_liberty $::env(LIB)
read_db   $res/6_final.odb
read_sdc  $res/6_final.sdc
read_spef $res/6_final.spef
puts "=== LIB [file tail $::env(LIB)]"
report_worst_slack -max -digits 3
report_tns -max -digits 3
report_worst_slack -min -digits 3
report_tns -min -digits 3
puts "=== worst setup endpoints"
report_checks -path_delay max -format end -group_path_count 5
puts "=== worst hold endpoints"
report_checks -path_delay min -format end -group_path_count 5
puts "=== worst setup path"
report_checks -path_delay max -fields {fanout cap slew} -digits 3
puts "=== worst hold path"
report_checks -path_delay min -digits 3
