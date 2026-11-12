# Netgen LVS: Magic-extracted layout vs powered Verilog + sky130_fd_sc_hd SPICE models.
# Env: LAYOUT (.spice)  VLOG (powered .v)  CELLS (std-cell .spice)  SETUP (sky130A_setup.tcl)  TOP  OUT (report)
set c1 [readnet spice $::env(LAYOUT)]
set c2 [readnet spice $::env(CELLS)]
readnet verilog $::env(VLOG) $c2
lvs "$c1 $::env(TOP)" "$c2 $::env(TOP)" $::env(SETUP) $::env(OUT) -json
