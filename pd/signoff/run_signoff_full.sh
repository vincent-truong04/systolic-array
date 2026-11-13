#!/bin/bash
# Full signoff on one finished ORFS run, with the flow that signed off EXP-014 (2026-11-12),
# parameterized. Two parallel lanes:
#   lane A (physical, on the PDK-cell GDS = the deliverable):
#     PDK-cell GDS merge -> KLayout DRC (ORFS sky130hd.lydrc, BEOL) -> Magic DRC (sky130A drc(full))
#     -> powered Verilog + unescape + nc pins -> Magic extraction -> Netgen LVS -> KLayout LVS
#   lane B (timing/function): STA + DRV at ss/tt/ff, IR/EM at ss/ff, SDF at ss/ff,
#     GLS zero-delay, GLS SDF ss, GLS SDF ff
# Not included: the KLayout FEOL+BEOL deck copy (hung > 6 h on EXP-012/014; Magic covers FEOL).
# Usage: run_signoff_full.sh <DESIGN_CONFIG> <FLOW_VARIANT> <out dir>
set -u
CFG=$1; VAR=$2; OUT=$3
REPO=$HOME/systolic-array
RES=$REPO/build/orfs/results/sky130hd/systolic_8x8/$VAR
OBJ=$REPO/build/orfs/objects/sky130hd/systolic_8x8/$VAR
TOP=systolic_top
export PDK_ROOT=$HOME/pdk
PDK=$PDK_ROOT/sky130A
MAGIC=$HOME/tools/magic/8.3.697/bin/magic
mkdir -p $OUT/lvs
source ~/OpenROAD-flow-scripts/env.sh >/dev/null 2>&1
LIB_SS=$HOME/pdk-libs/sky130_fd_sc_hd/sky130_fd_sc_hd__ss_100C_1v60.lib
LIB_TT=$HOME/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
LIB_FF=$HOME/OpenROAD-flow-scripts/tools/OpenROAD/test/sky130hd/sky130_fd_sc_hd__ff_n40C_1v95.lib
FLOW=$HOME/OpenROAD-flow-scripts/flow
MK="make -C $FLOW DESIGN_CONFIG=$CFG WORK_HOME=$REPO/build/orfs NUM_CORES=8 FLOW_VARIANT=$VAR"
GDS=$OUT/6_final_pdkcells.gds
step() { local name=$1; shift; local s=$(date +%s); "$@" > $OUT/$name.log 2>&1; local rc=$?;
         echo "$(date +%T) STEP $name EXIT=$rc $(( $(date +%s)-s ))s" | tee -a $OUT/summary.txt; return 0; }

laneA() {
  # Final GDS with the open_pdks cell GDS (ORFS's a2111oi_0 GDS fails Magic licon.8a, EXP-014).
  step gds_pdkcells /usr/bin/time -v klayout -zz -rd design_name=$TOP -rd in_def=$RES/6_final.def \
       -rd in_files="$PDK/libs.ref/sky130_fd_sc_hd/gds/sky130_fd_sc_hd.gds" -rd seal_file="" \
       -rd out_file=$GDS -rd tech_file=$OBJ/klayout.lyt -rd layer_map= -r $FLOW/util/def2stream.py
  step drc_klayout_beol /usr/bin/time -v klayout -zz -rd in_gds=$GDS \
       -rd report_file=$OUT/drc_klayout_beol.lyrdb -r $FLOW/platforms/sky130hd/drc/sky130hd.lydrc
  grep -c "<value>" $OUT/drc_klayout_beol.lyrdb > $OUT/drc_klayout_beol_count.txt
  step drc_magic env GDS=$GDS TOP=$TOP OUT=$OUT/magic_drc /usr/bin/time -v $MAGIC -dnull -noconsole \
       -rcfile $PDK/libs.tech/magic/sky130A.magicrc $REPO/pd/signoff/magic_drc.tcl
  # LVS schematic: powered Verilog, escaped names replaced (Netgen 1.5.133), unconnected pins explicit.
  step lvs_pwr_verilog env RES=$RES OUT=$OUT/lvs/6_final_pwr.v openroad -no_init -exit $REPO/pd/signoff/write_pwr_verilog.tcl
  step lvs_unescape python3 $REPO/pd/signoff/unescape_verilog.py $OUT/lvs/6_final_pwr.v $OUT/lvs/6_final_pwr_noesc.v
  step lvs_nc_pins python3 $REPO/pd/signoff/add_nc_pins.py $OUT/lvs/6_final_pwr_noesc.v \
       $PDK/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice $OUT/lvs/6_final_pwr_nc.v
  ( cd $OUT/lvs && step magic_ext env GDS=$GDS TOP=$TOP OUT=$OUT/lvs/${TOP}_ext.spice /usr/bin/time -v $MAGIC \
       -dnull -noconsole -rcfile $PDK/libs.tech/magic/sky130A.magicrc $REPO/pd/signoff/magic_ext.tcl )
  step lvs_netgen env LAYOUT=$OUT/lvs/${TOP}_ext.spice VLOG=$OUT/lvs/6_final_pwr_nc.v \
       CELLS=$PDK/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice SETUP=$PDK/libs.tech/netgen/sky130A_setup.tcl \
       TOP=$TOP OUT=$OUT/lvs/netgen_lvs.rpt /usr/bin/time -v netgen-lvs -batch source $REPO/pd/signoff/netgen_lvs.tcl
  step lvs_cdl $MK $OBJ/6_final_concat.cdl
  step lvs_klayout /usr/bin/time -v klayout -b -rd in_gds=$GDS -rd cdl_file=$OBJ/6_final_concat.cdl \
       -rd top_cell=$TOP -rd report_file=$OUT/lvs_klayout.lvsdb -r $FLOW/platforms/sky130hd/lvs/sky130hd.lylvs
}
laneB() {
  export PATH=$REPO/.venv/bin:$PATH
  cd $REPO
  for c in ss:$LIB_SS tt:$LIB_TT ff:$LIB_FF; do n=${c%%:*}; l=${c#*:}
    step sta_$n env RES=$RES LIB=$l openroad -no_init -exit -threads 4 pd/sta/corner_sta.tcl
    step drv_$n env RES=$RES LIB=$l openroad -no_init -exit -threads 4 pd/sta/drv_check.tcl
  done
  step ir_ss env RES=$RES LIB=$LIB_SS VDD=1.60 SRC=FULL OUT=$OUT/ir_ss openroad -no_init -exit -threads 4 pd/sta/irem.tcl
  step ir_ff env RES=$RES LIB=$LIB_FF VDD=1.95 SRC=FULL OUT=$OUT/ir_ff openroad -no_init -exit -threads 4 pd/sta/irem.tcl
  step sdf_ss env RES=$RES LIB=$LIB_SS OUT=$OUT/ss.sdf openroad -no_init -exit pd/sta/write_sdf.tcl
  step sdf_ff env RES=$RES LIB=$LIB_FF OUT=$OUT/ff.sdf openroad -no_init -exit pd/sta/write_sdf.tcl
  step gls_prep_ss python3 tb/gls/sanitize_names.py $RES/6_final.v $OUT/ss.sdf $OUT/6_final_gls.v $OUT/ss_gls.sdf
  step gls_prep_ff python3 tb/gls/sanitize_names.py $RES/6_final.v $OUT/ff.sdf $OUT/6_final_gls_ff.v $OUT/ff_gls.sdf
  step gls_func   make -C tb/gls NETLIST=$RES/6_final.v TAG=func_$VAR
  step gls_sdf_ss make -C tb/gls NETLIST=$OUT/6_final_gls.v SDF=$OUT/ss_gls.sdf TAG=sdf_ss_$VAR
  step gls_sdf_ff make -C tb/gls NETLIST=$OUT/6_final_gls_ff.v SDF=$OUT/ff_gls.sdf TAG=sdf_ff_$VAR
}
echo "$(date +%T) START $VAR" > $OUT/summary.txt
laneA & A=$!
laneB & B=$!
wait $A $B
echo "$(date +%T) DONE" >> $OUT/summary.txt
