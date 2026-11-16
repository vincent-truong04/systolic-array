# Magic antenna check on a GDS (same steps as open_pdks libs.tech/magic/check_antenna.py, which
# expects a .mag file). Env: GDS, TOP. Run from a scratch dir (extraction writes .ext files).
crashbackups stop
drc off
snap internal
gds readonly true
gds rescale false
gds read $::env(GDS)
load $::env(TOP) -dereference
select top cell
expand
extract do local
extract no all
extract all
antennacheck debug
antennacheck
quit -noprompt
