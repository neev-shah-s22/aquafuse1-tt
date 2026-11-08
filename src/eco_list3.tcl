# ser47 (8 Nov, DR013 update 19): stage-3 ECO list, applied on the finished stage-2 route (which reproduces ser46's).
# 12 swaps picked on ser46's own wiring (VPS ser46c_r1.swaps; OpenSTA on gds run 42482263144's unpowered final/nl +
# signoff SDC 426fd8a9 + min/nom/max SPEF, 9 corners): with them every update-18 term is met except 2 data pins at max_ss
# on _10650_ (8.04 vs 7.80 ns; driver _27526_ already aoi221_4, the largest), which the buffer below drives instead.
set ::aq_eco_lists [dict create]
dict set ::aq_eco_lists all [list \
    {_17014_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_17030_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_17077_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_27165_ gf180mcu_fd_sc_mcu7t5v0__xnor2_2} \
    {_27356_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[77].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[82].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {clkbuf_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_1_0__f_u_b1.g_slot[0].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[49].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {fanout905 gf180mcu_fd_sc_mcu7t5v0__buf_2} \
]
dict set ::aq_eco_lists buffers [list \
    {_27526_ ZN gf180mcu_fd_sc_mcu7t5v0__buf_8} \
]
