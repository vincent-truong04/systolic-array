#!/bin/bash
# Re-merge EXP-014 final GDS with the open_pdks (c6d73a35) sky130_fd_sc_hd GDS instead of ORFS's platform copy.
# Same command ORFS uses in do-gds-merged (Makefile), only in_files and out_file changed.
source ~/OpenROAD-flow-scripts/env.sh >/dev/null 2>&1
R=$HOME/systolic-array/build/orfs; V=sky130hd/systolic_8x8/ss_clk11_signoff
OUT=$HOME/systolic-array/build/signoff/exp014/pdkgds
/usr/bin/time -v klayout -zz -rd design_name=systolic_top \
  -rd in_def=$R/results/$V/6_final.def \
  -rd in_files="$HOME/pdk/sky130A/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds" \
  -rd seal_file="" \
  -rd out_file=$OUT/6_final_pdkcells.gds \
  -rd tech_file=$R/objects/$V/klayout.lyt \
  -rd layer_map= \
  -r $HOME/OpenROAD-flow-scripts/flow/util/def2stream.py
