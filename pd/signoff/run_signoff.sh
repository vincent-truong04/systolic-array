#!/bin/bash
# All available signoff checks on one finished ORFS run, in two parallel lanes:
#   lane A (physical): ORFS KLayout DRC (BEOL) -> KLayout DRC FEOL+BEOL deck copy -> ORFS KLayout LVS
#   lane B (timing/function): STA + DRV at ss/tt/ff, IR/EM at ss/ff, SDF at ss/ff,
#                             GLS zero-delay, GLS SDF ss, GLS SDF ff
# Usage: run_signoff.sh <DESIGN_CONFIG> <FLOW_VARIANT> <out dir>
set -u
CFG=$1; VAR=$2; OUT=$3
REPO=$HOME/systolic-array
RES=$REPO/build/orfs/results/sky130hd/systolic_8x8/$VAR
mkdir -p $OUT
source ~/OpenROAD-flow-scripts/env.sh >/dev/null 2>&1
# venv (cocotb) is put on PATH inside laneB only: its python lacks pyyaml, which ORFS defaults.py needs (lane A make lvs failed, 2026-11-11)
LIB_SS=$HOME/pdk-libs/sky130_fd_sc_hd/sky130_fd_sc_hd__ss_100C_1v60.lib
LIB_TT=$HOME/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
LIB_FF=$HOME/OpenROAD-flow-scripts/tools/OpenROAD/test/sky130hd/sky130_fd_sc_hd__ff_n40C_1v95.lib
MK="make -C $HOME/OpenROAD-flow-scripts/flow DESIGN_CONFIG=$CFG WORK_HOME=$REPO/build/orfs NUM_CORES=8 FLOW_VARIANT=$VAR"
step() { local name=$1; shift; local s=$(date +%s); "$@" > $OUT/$name.log 2>&1; local rc=$?;
         echo "$(date +%T) STEP $name EXIT=$rc $(( $(date +%s)-s ))s" | tee -a $OUT/summary.txt; return 0; }

laneA() {
  step drc_orfs_beol $MK drc
  step drc_klayout_feol_beol /usr/bin/time -v klayout -zz -rd in_gds=$RES/6_final.gds \
       -rd report_file=$OUT/drc_feol_beol.lyrdb -r $REPO/pd/signoff/sky130hd_feol_beol.lydrc
  step lvs_klayout $MK lvs
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
