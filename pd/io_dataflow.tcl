# EXP-015: pins follow the dataflow (A rows enter left, B columns enter top, C rows drain out the bottom).
# Sourced by ORFS floorplan.tcl via IO_CONSTRAINTS; place_pins honours these regions in 3_2_place_iop.
proc bits {bus n} { set l {}; for {set i 0} {$i < $n} {incr i} { lappend l "${bus}\[$i\]" }; return $l }
set_io_pin_constraint -pin_names [concat {clk rst in_valid in_first in_last in_ready} [bits a_col 64]] -region left:*   -group -order
set_io_pin_constraint -pin_names [bits b_row 64]                                                       -region top:*    -group -order
set_io_pin_constraint -pin_names [concat [bits out_data 256] [bits out_row 3] {out_valid}]             -region bottom:* -group -order
