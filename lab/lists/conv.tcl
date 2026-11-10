# ECO lab 5 (10 Nov): ser52c_r1.swaps, the 8 swaps picked on ser52's own wiring (VPS vps-074593ae; on that wiring they
# meet every update 18 term at all 9 corners). Applied by the stage hook on ser52's finished route.
# control: what a stage 3 does today (in-row fit, then legalization, full global route).
set ::aq_eco_stages {all}
set ::aq_eco_fit 1
set ::aq_eco_fit_um 80.0
set ::aq_eco_dpl 1
set ::aq_eco_regrt full
set ::aq_eco_lists [dict create]
dict set ::aq_eco_lists all [list \
    {_16745_ gf180mcu_fd_sc_mcu7t5v0__xnor2_2} \
    {_17020_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_20632_ gf180mcu_fd_sc_mcu7t5v0__nand4_2} \
    {_26445_ gf180mcu_fd_sc_mcu7t5v0__nor3_2} \
    {_29053_ gf180mcu_fd_sc_mcu7t5v0__aoi21_2} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[90].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[57].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
]
