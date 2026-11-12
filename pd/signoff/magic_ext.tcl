# Magic extraction of the final GDS to a SPICE netlist for Netgen LVS (no parasitics).
# Env: GDS  TOP  OUT (output .spice path; .ext files go to the cwd)
gds readonly true
gds read $::env(GDS)
load $::env(TOP)
select top cell
extract no capacitance
extract no coupling
extract no resistance
extract no adjustment
extract all
ext2spice lvs
ext2spice -o $::env(OUT)
puts "MAGIC_EXT_DONE $::env(OUT)"
quit -noprompt
