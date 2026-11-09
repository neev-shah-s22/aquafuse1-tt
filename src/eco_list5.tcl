# ser50 (9 Nov, DR013 update 19): stage-5 ECO list, applied on the finished stage-4 route (which reproduces ser48's).
# ser49's 13 swaps (picked on ser48's own wiring) plus the 5 that ser49's own wiring still needed (VPS ser49c_r1.swaps;
# OpenSTA on gds run 42546166971's unpowered final/nl + signoff SDC + min/nom/max SPEF, 9 corners: with them every
# update-18 term is met at all 9 corners). They are folded into stage 5, not a stage 6: ser49's job ran 5 h 56 min of
# the 6 h cap. The in-row fit reach goes 40 -> 80 um: at 40 um ser49 fitted 5 of 13 cells and legalization moved 136.
set ::aq_eco_fit 1
set ::aq_eco_fit_um 80.0
set ::aq_eco_lists [dict create]
dict set ::aq_eco_lists all [list \
    {_16747_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_16800_ gf180mcu_fd_sc_mcu7t5v0__nor3_4} \
    {_16843_ gf180mcu_fd_sc_mcu7t5v0__nand2_2} \
    {_17048_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_17071_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_20157_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_20162_ gf180mcu_fd_sc_mcu7t5v0__nand4_2} \
    {_20181_ gf180mcu_fd_sc_mcu7t5v0__nand3_2} \
    {_25485_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[86].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8} \
    {clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[55].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {hold1776 gf180mcu_fd_sc_mcu7t5v0__clkbuf_2} \
    {u_b1.u_wg.u_idx.g_bit[5].u_l gf180mcu_fd_sc_mcu7t5v0__latq_2} \
    {_17081_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_19013_ gf180mcu_fd_sc_mcu7t5v0__xor2_2} \
    {_20450_ gf180mcu_fd_sc_mcu7t5v0__nand4_2} \
    {_27394_ gf180mcu_fd_sc_mcu7t5v0__oai21_2} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[83].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
]
