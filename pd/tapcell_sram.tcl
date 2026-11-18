# tapcell_sram.tcl (TAPCELL_TCL, EXP-035 DRAFT): the platform's tapcell command plus an explicit macro
# halo. tapcell cuts the standard-cell rows under the macro and SRAM_HALO um around it, so no cell is
# placed there: room for routes into the macro pins (dout1 sits inside the macro outline) and for the
# power straps.
tapcell \
  -distance 14 \
  -tapcell_master "$::env(TAP_CELL_NAME)" \
  -halo_width_x $::env(SRAM_HALO) \
  -halo_width_y $::env(SRAM_HALO)
