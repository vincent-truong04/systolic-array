# macro_place_sram.tcl (MACRO_PLACEMENT_TCL, EXP-035 DRAFT): manual placement of the one weight-buffer
# macro. Placed (FIRM) macros are left alone by rtl_macro_placer, so this is the whole macro placement.
# MX = mirror about the x axis: dout1 (y 213.6 in the LEF) ends up 26.3 um above the macro's lower
# edge, facing the PE array below; din0/wmask0 (y 2.8) end up at the top, facing the wr_* pins.
place_macro -macro_name u_bbuf -location [list $::env(SRAM_X) $::env(SRAM_Y)] -orientation MX
