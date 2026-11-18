# pdn_sram.tcl (PDN_TCL, EXP-035 DRAFT): platform sky130hd grid + power hookup for the OpenRAM macro.
#
# Why the platform pdn.tcl isn't enough (checked in the macro LEF, 2026-11-17):
#   - the macro's supply pins are named vdd / gnd. The platform global connections match VPWR/VGND/
#     VDD/VSS only, so the macro would stay unpowered.
#   - its supply pins are 0.49 um met3 squares (vdd 1339, gnd 1216) in rows across the macro, not
#     a met4 ring. The platform's default macro grids only connect met4<->met5, which assumes met4
#     pins. Here met4 straps must run over the macro and drop met3-met4 vias on the pads they cross.
#   - the macro has no met4/met5 obstructions, so straps over it are allowed.

# macro supplies (the stdcell rules come from the platform global_connect.tcl)
add_global_connection -net {VDD} -inst_pattern {u_bbuf} -pin_pattern {^vdd$} -power
add_global_connection -net {VSS} -inst_pattern {u_bbuf} -pin_pattern {^gnd$} -ground
global_connect

set_voltage_domain -name {CORE} -power {VDD} -ground {VSS}

# standard cell grid (unchanged from platforms/sky130hd/pdn.tcl)
define_pdn_grid -name {grid} -voltage_domains {CORE} -pins {met5}
add_pdn_stripe -grid {grid} -layer {met1} -width {0.48} -pitch {5.44} -offset {0} -followpins
add_pdn_stripe -grid {grid} -layer {met4} -width {1.600} -pitch {27.140} -offset {13.570}
add_pdn_stripe -grid {grid} -layer {met5} -width {1.600} -pitch {27.200} -offset {13.600}
add_pdn_connect -grid {grid} -layers {met1 met4}
add_pdn_connect -grid {grid} -layers {met4 met5}

# macro grid: denser met4 straps over the macro (pitch 13.57 = half the core pitch, so each net
# crosses more pad rows), vias to the met3 pads, and to the core met5 straps above.
define_pdn_grid -name {sram} -voltage_domains {CORE} -macro -instances {u_bbuf} \
  -halo {2.0 2.0 2.0 2.0} -grid_over_boundary
add_pdn_stripe -grid {sram} -layer {met4} -width {1.600} -pitch {13.570} -offset {6.785}
add_pdn_connect -grid {sram} -layers {met3 met4}
add_pdn_connect -grid {sram} -layers {met4 met5}
