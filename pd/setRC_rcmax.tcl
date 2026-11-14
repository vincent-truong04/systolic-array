# setRC_rcmax.tcl: ORFS platforms/sky130hd/setRC.tcl scaled toward the open_pdks max RC corner,
# used as LAYER_PARASITICS_FILE so placement/CTS/GRT repair estimate with max-corner wires (EXP-031).
# Scale factors (2026-11-13, Claude): total net C and R summed from SPEFs re-extracted on the same
# EXP-025-ECO layout (pd/sta/rc_corner_sta.tcl): max.calibre vs ORFS rcx_patterns.rules
# C 207.2/189.0 pF = 1.0965, R 3.684/3.233 MOhm = 1.1392 -> C x1.10, R x1.14 on every layer and via.
# A single design-wide factor: per-layer max/nom ratios are not available from the SPEF totals.
set_layer_rc -layer li1 -capacitance 1.648900E-04 -resistance 8.180640E-02
set_layer_rc -layer met1 -capacitance 1.896125E-04 -resistance 1.374441E-03
set_layer_rc -layer met2 -capacitance 1.498563E-04 -resistance 1.392305E-03
set_layer_rc -layer met3 -capacitance 2.364582E-04 -resistance 1.895603E-04
set_layer_rc -layer met4 -capacitance 1.629408E-04 -resistance 1.916260E-04
set_layer_rc -layer met5 -capacitance 1.694957E-04 -resistance 2.092561E-05

set_layer_rc -via mcon -resistance 1.054403E-02
set_layer_rc -via via -resistance 5.130000E-03
set_layer_rc -via via2 -resistance 3.840416E-03
set_layer_rc -via via3 -resistance 4.293639E-04
set_layer_rc -via via4 -resistance 6.612000E-06

set_wire_rc -signal -layer met1
set_wire_rc -clock -layer met3
