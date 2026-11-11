# Electrical design-rule checks (max slew / capacitance / fanout) at ONE library corner.
# Env: RES=<ORFS results dir>  LIB=<liberty file>
read_liberty $::env(LIB)
read_db   $::env(RES)/6_final.odb
read_sdc  $::env(RES)/6_final.sdc
read_spef $::env(RES)/6_final.spef
puts "=== LIB [file tail $::env(LIB)]"
puts "max_slew violations:        [sta::max_slew_violation_count]"
puts "max_capacitance violations: [sta::max_capacitance_violation_count]"
puts "max_fanout violations:      [sta::max_fanout_violation_count]"
report_check_types -max_slew -max_capacitance -max_fanout -violators -digits 3
puts "=== worst slew / cap margins"
report_check_types -max_slew -max_capacitance -digits 3
