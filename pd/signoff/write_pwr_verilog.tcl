# Powered Verilog (VPWR/VGND/VPB/VNB connected) of the final layout, as the schematic side for Netgen LVS.
# Env: RES=<ORFS results dir>  OUT=<output .v>
read_db $::env(RES)/6_final.odb
write_verilog -include_pwr_gnd $::env(OUT)
