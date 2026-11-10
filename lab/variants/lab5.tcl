# ECO lab 5 (10 Nov): ser52's routed ODB is the input, so the first route is skipped. The first ECO is a no-op (empty
# src/eco_list.tcl, no stages, no planned moves, no legalization, nothing ripped up) that only re-makes global routing,
# leaving this process as a real build's stage 2 leaves it. The stage hook then applies src/eco_list2.tcl.
set ::aq_eco_mode lab_post
set ::aq_eco_stages {}
set ::aq_eco_dpl 0
set ::aq_eco_regrt full
unset -nocomplain ::aq_eco_moves
