# remap_fill_layers.py: move ORFS density-fill shapes to the sky130 metal-fill GDS layers.
# ORFS (def2stream with platforms/sky130hd klayout.lyt) writes DEF FILLS as <n>/28 with n = an
# unmapped index (met2..met5 -> 7/9/11/13 on this flow, identified 2026-11-14 by shape counts
# 158/40622/34955/8675 = density_fill totals per layer). sky130 fill layers (Magic sky130A.tech
# "calma MET<n>FILL", KLayout met_min_ca_density.lydrc): met1 36/28, met2 41/28, met3 34/28,
# met4 51/28, met5 59/28. Unmapped fill would be ignored by DRC/density decks and the foundry.
# Usage: klayout -b -rd in_gds=<in> -rd out_gds=<out> -r remap_fill_layers.py
import pya
MAP = {(7, 28): (41, 28), (9, 28): (34, 28), (11, 28): (51, 28), (13, 28): (59, 28)}
ly = pya.Layout()
ly.read(in_gds)
moved = {}
for li in list(ly.layer_indexes()):
    info = ly.get_info(li)
    key = (info.layer, info.datatype)
    if key in MAP:
        tgt = ly.layer(pya.LayerInfo(*MAP[key]))
        n = 0
        for cell in ly.each_cell():
            shapes = cell.shapes(li)
            n += shapes.size()
            cell.shapes(tgt).insert(shapes)
            shapes.clear()
        moved[key] = n
        ly.delete_layer(li)
for k, v in sorted(moved.items()):
    print(f"moved {k[0]}/{k[1]} -> {MAP[k][0]}/{MAP[k][1]}: {v} shapes")
left = [ly.get_info(li) for li in ly.layer_indexes() if ly.get_info(li).datatype == 28 and (ly.get_info(li).layer, 28) not in MAP.values()]
print("other datatype-28 layers left:", [str(i) for i in left])
ly.write(out_gds)
print("wrote", out_gds)
