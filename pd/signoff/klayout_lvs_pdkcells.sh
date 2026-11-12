#!/bin/bash
# KLayout LVS (ORFS rule, same command as Makefile 6_lvs.lvsdb) on the PDK-cell GDS.
source ~/OpenROAD-flow-scripts/env.sh >/dev/null 2>&1
O=$HOME/systolic-array/build/orfs/objects/sky130hd/systolic_8x8/ss_clk11_signoff
D=$HOME/systolic-array/build/signoff/exp014/pdkgds
/usr/bin/time -v klayout -b -rd in_gds=$D/6_final_pdkcells.gds \
  -rd cdl_file=$O/6_final_concat.cdl -rd top_cell=systolic_top \
  -rd report_file=$D/6_lvs_pdkcells.lvsdb -r $HOME/OpenROAD-flow-scripts/flow/platforms/sky130hd/lvs/sky130hd.lylvs
echo "KLVS_EXIT=$?"
