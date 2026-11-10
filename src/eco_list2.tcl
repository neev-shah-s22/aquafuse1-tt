# ser54 (10 Nov, DR013 update 19): stage 2 keeps only the two buffers (each drives a routed detour, so they are placed
# after the first route); every swap of ser52's stage 2 and the 76 guard-band swaps moved into src/eco_list.tcl, applied
# before the first route. The stage still re-routes and runs the antenna passes, as in every build since ser44.
set ::aq_eco_fit 1
set ::aq_eco_fit_um 80.0
set ::aq_eco_lists [dict create]
dict set ::aq_eco_lists buffers [list \
    {_27526_ ZN gf180mcu_fd_sc_mcu7t5v0__buf_8} \
    {_16973_ ZN gf180mcu_fd_sc_mcu7t5v0__buf_8} \
]
