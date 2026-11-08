# ser48 (8 Nov, DR013 update 19): stage-4 ECO list, applied on the finished stage-3 route (which reproduces ser47's).
# 9 swaps picked on ser47's own wiring (VPS ser47c_r2.swaps; OpenSTA on gds run 42500876040's unpowered final/nl +
# signoff SDC + min/nom/max SPEF, 9 corners): with them every update-18 term is met except 5 data pins on _16250_
# (driver _16973_ already nor2_4, the largest nor2; 0.378 pF of wire to 4 loads), 9.06 vs 7.80 ns at max_ss, which the
# buffer below drives instead (lumped what-if, VPS ser48_buf_whatif: buf_8 2.40 ns max_ss, 1.30 max_tt, 0.79 max_ff).
set ::aq_eco_lists [dict create]
dict set ::aq_eco_lists all [list \
    {_17020_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_17069_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_25370_ gf180mcu_fd_sc_mcu7t5v0__nand2_2} \
    {_27816_ gf180mcu_fd_sc_mcu7t5v0__aoi221_2} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[21].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[70].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8} \
    {clkbuf_1_1__f__16260_ gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[76].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
]
dict set ::aq_eco_lists buffers [list \
    {_16973_ ZN gf180mcu_fd_sc_mcu7t5v0__buf_8} \
]
