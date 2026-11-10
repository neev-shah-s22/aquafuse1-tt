# ECO lab 6 (10 Nov, DR013 update 19): the final stage for ser52's route, from lab 5.
#   - the 3 of ser52c_r1's swaps that fit in place in lab 5 (_17020_, _29053_, g_ent[57] leaf);
#   - lab5w4, what-if-checked on lab5fonone's own wiring (VPS vps-074593ae, all update 18 terms clean at 9 corners):
#     * the 5 swaps that found no free span (the two clock fixes as clkbuf_4, the same 14 sites as clkbuf_3);
#     * 2 downsizes that free the sites their tap segments lack (_16963_ nor3_2 -> nor3_1, clkbuf_0__16244_ clkbuf_4 ->
#       clkbuf_2).
# ECO lab 7 (10 Nov): lab 6 left only the g_ent[90] root unplaced (its segment slide found 8 cells, not 6: a cell fitted
# before it had taken the free sites), so it now comes right after the two downsizes; the fit takes cells in list order.
# Fit-only with the segment slide (at most 8 cells per slide), no legalization, guides kept (lab 5's fo_none: 162 nets moved > 1 %).
set ::aq_eco_stages {all}
set ::aq_eco_fit 1
set ::aq_eco_fit_um 80.0
set ::aq_eco_fit_only 1
set ::aq_eco_fit_slide 8
set ::aq_eco_dpl 0
set ::aq_eco_regrt none
set ::aq_eco_lists [dict create]
dict set ::aq_eco_lists all [list \
    {_16963_ gf180mcu_fd_sc_mcu7t5v0__nor3_1} \
    {clkbuf_0__16244_ gf180mcu_fd_sc_mcu7t5v0__clkbuf_2} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[90].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {_17020_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_29053_ gf180mcu_fd_sc_mcu7t5v0__aoi21_2} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[57].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {_16745_ gf180mcu_fd_sc_mcu7t5v0__xnor2_2} \
    {_20632_ gf180mcu_fd_sc_mcu7t5v0__nand4_2} \
    {_26445_ gf180mcu_fd_sc_mcu7t5v0__nor3_2} \
    {clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
]
