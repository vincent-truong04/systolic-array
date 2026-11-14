# Final layout + metal density fill: EXP-025-ECO2 with USE_FILL=1 (ORFS density_fill with
# platforms/sky130hd/fill.json: met1..met5 only). Used on a copy of variant clk10_u70_lanes_eco2
# (make clean_finish + finish), so placement/routing/ECOs are unchanged; only 6_1_fill onward reruns.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk10_u70_lanes.mk
export USE_FILL = 1
