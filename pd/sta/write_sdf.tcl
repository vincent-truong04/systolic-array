# Write an SDF of a finished ORFS run at ONE library corner (for gate-level simulation).
# Env: RES, LIB, OUT (sdf path)
read_liberty $::env(LIB)
read_db   $::env(RES)/6_final.odb
read_sdc  $::env(RES)/6_final.sdc
read_spef $::env(RES)/6_final.spef
write_sdf -divider . -digits 4 $::env(OUT)
puts "wrote $::env(OUT)"
