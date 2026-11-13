# EXP-020: EXP-018 (util 75, PLACE_DENSITY 0.85, SETUP_SLACK_MARGIN 0) + CELL_PAD_IN_SITES_DETAIL_PLACEMENT 0 -> 1.
# One empty site left/right of each cell in every legalization, so repair can upsize in place (see EXP-018 follow-up).
include $(dir $(DESIGN_CONFIG))config_ss_signoff_clk11_pins_ant_u75.mk
export CELL_PAD_IN_SITES_DETAIL_PLACEMENT = 1
