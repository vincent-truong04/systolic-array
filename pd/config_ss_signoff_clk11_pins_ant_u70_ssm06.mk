# EXP-022: EXP-021 (util 70, PLACE_DENSITY 0.80) + SETUP_SLACK_MARGIN 0 -> 0.6 ns.
# Repair (floorplan/CTS/GRT) aims for +0.6 to cover the ~0.57 ns lost after repair at 70% (EXP-021 follow-up).
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11_pins_ant_u70.mk
export SETUP_SLACK_MARGIN = 0.6
