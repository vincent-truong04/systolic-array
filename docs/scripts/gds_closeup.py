# gds_closeup.py: KLayout batch render of a GDS window (docs/images/gds_closeup.png).
# Usage: GDS=build/signoff/exp033holdeco_r3/6_final_pdkcells.gds LYP=$HOME/pdk/sky130A/libs.tech/klayout/tech/sky130A.lyp \
#        OUTDIR=docs/images SHOTS="gds_closeup.png,300,300,330,322,1400,1000" klayout -b -r docs/scripts/gds_closeup.py
# SHOTS = name,x0,y0,x1,y1 (um),width,height (px); several separated by ";".
import pya, os
gds = os.environ["GDS"]; lyp = os.environ["LYP"]
v = pya.LayoutView()
v.load_layout(gds, 0)
v.load_layer_props(lyp)
v.set_config("background-color", "#000000")
v.set_config("grid-visible", "false")
v.set_config("text-visible", "false")
v.max_hier()
for spec in os.environ["SHOTS"].split(";"):
    name, x0, y0, x1, y1, w, h = spec.split(",")
    v.zoom_box(pya.DBox(float(x0), float(y0), float(x1), float(y1)))
    v.save_image(os.path.join(os.environ["OUTDIR"], name), int(w), int(h))
    print("saved", name)
