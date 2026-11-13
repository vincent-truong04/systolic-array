# EXP-019: EXP-018 (util 75, PLACE_DENSITY 0.85) + SETUP_SLACK_MARGIN 0 -> 0.5 ns.
# Repair (floorplan/CTS/GRT) aims for +0.5 ns slack instead of stopping at 0.
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11_pins_ant_u75.mk
export SETUP_SLACK_MARGIN = 0.5
