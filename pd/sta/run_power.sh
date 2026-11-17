#!/bin/bash
# Power characterization of one finished ORFS run at tt (PWR-001 method):
# tb/gls/test_power.py zero-delay + tt SDF-timed GLS -> FST -> VCD -> pd/sta/power_windows.tcl
# per workload window -> pd/sta/power_groups.py summary.
# Usage: run_power.sh <FLOW_VARIANT> <out dir>
set -u
V=$1; O=$2; R=$HOME/systolic-array; cd $R; export PATH=$R/.venv/bin:$PATH
source ~/OpenROAD-flow-scripts/env.sh >/dev/null 2>&1
RES=$R/build/orfs/results/sky130hd/systolic_8x8/$V
LIB_TT=$HOME/OpenROAD-flow-scripts/flow/platforms/sky130hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib
mkdir -p $O
log() { echo "$(date +%T) $*" | tee -a $O/status.log; }
log "START $V"
RES=$RES LIB=$LIB_TT OUT=$O/tt.sdf openroad -no_init -exit pd/sta/write_sdf.tcl > $O/sdf_tt.log 2>&1; log "sdf_tt EXIT=$?"
python3 tb/gls/sanitize_names.py $RES/6_final.v $O/tt.sdf $O/6_final_gls_tt.v $O/tt_gls.sdf > $O/sanitize.log 2>&1; log "sanitize EXIT=$? $(tail -1 $O/sanitize.log)"
sim() { # tag netlist windows [sdf]
  local args="NETLIST=$2"; [ -n "${4:-}" ] && args="$args SDF=$4"
  /usr/bin/time -v make -C tb/gls $args TAG=$1 WAVES=1 COCOTB_TEST_MODULES=test_power POWER_WINDOWS=$3 > $O/gls_$1.log 2>&1
  log "sim $1 EXIT=$? $(grep -oE 'TESTS=[0-9]+ PASS=[0-9]+ FAIL=[0-9]+' $O/gls_$1.log | tail -1)"
}
sim pwr_zd_$V $RES/6_final.v $O/windows_zd.json &
sim pwr_sdf_$V $O/6_final_gls_tt.v $O/windows_sdf.json $O/tt_gls.sdf &
wait
for m in zd sdf; do
  [ -f $O/windows_$m.json ] || { log "$m: no windows file, skip"; continue; }
  fst2vcd -f tb/gls/sim_build_pwr_${m}_$V/systolic_top.fst -o $O/$m.vcd > /dev/null 2>&1; log "fst2vcd $m EXIT=$? $(du -h $O/$m.vcd | cut -f1)"
  if [ $m = sdf ]; then
    python3 tb/gls/unsanitize_vcd.py $RES/6_final.v $O/sdf.vcd $O/sdf_named.vcd > $O/unsanitize.log 2>&1
    log "unsanitize EXIT=$? $(cat $O/unsanitize.log)"; mv $O/sdf_named.vcd $O/sdf.vcd
  fi
  W=$(python3 -c "
import json; w=json.load(open('$O/windows_$m.json')); ps=lambda t:int(round(t*1000))
out=[f'{k} {ps(w[k][0])} {ps(w[k][1])}' for k in ('idle','dense','sparse')]
out+=[f'drain{i+1} {ps(a)} {ps(b)}' for i,(a,b) in enumerate(w['drain'])]
print(';'.join(out))")
  mkdir -p $O/$m
  RES=$RES LIB=$LIB_TT VCD=$O/$m.vcd SCOPE=systolic_top WINDOWS="$W" OUT=$O/$m \
    /usr/bin/time -v openroad -no_init -exit -threads 4 pd/sta/power_windows.tcl > $O/power_$m.log 2>&1
  log "power $m EXIT=$?"
done
python3 pd/sta/power_groups.py $O $O/windows_sdf.json $RES/6_final.v > $O/summary.txt 2>&1; log "summary EXIT=$?"
rm -f $O/zd.vcd $O/sdf.vcd   # large; the FSTs stay in tb/gls/sim_build_pwr_*
log DONE
