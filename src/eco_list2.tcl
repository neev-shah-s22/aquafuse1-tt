# ser43 (7 Nov, DR013 update 19): stage-2 ECO list, applied on the finished route just before write_views. 26 swaps
# picked on ser42's own wiring (VPS ser42c_r1.swaps; OpenSTA on gds run 42331237161's unpowered final/nl + signoff SDC
# 426fd8a9 + min/nom/max SPEF, 9 corners): with them every DR013 update-18 term is met except 2 data pins at max_ss
# (_10650_, 7.81 vs 7.80 ns: a 0.187 pF router detour that stage 2 re-routes); hold >= +0.1502 ns, latch 0 violated.
set ::aq_eco_lists [dict create]
dict set ::aq_eco_lists all [list \
    {_16279_ gf180mcu_fd_sc_mcu7t5v0__clkinv_2} \
    {_16894_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_16908_ gf180mcu_fd_sc_mcu7t5v0__or3_2} \
    {_17035_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_17073_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_17079_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_17222_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_18969_ gf180mcu_fd_sc_mcu7t5v0__aoi222_2} \
    {_21007_ gf180mcu_fd_sc_mcu7t5v0__nand4_4} \
    {_25494_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_27380_ gf180mcu_fd_sc_mcu7t5v0__oai21_2} \
    {_27526_ gf180mcu_fd_sc_mcu7t5v0__aoi221_4} \
    {_29472_ gf180mcu_fd_sc_mcu7t5v0__nor4_2} \
    {_30078_ gf180mcu_fd_sc_mcu7t5v0__aoi22_2} \
    {_30109_ gf180mcu_fd_sc_mcu7t5v0__nor4_2} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[80].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[81].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[87].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[88].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[35].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[48].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[60].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[71].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {input12 gf180mcu_fd_sc_mcu7t5v0__buf_2} \
]
