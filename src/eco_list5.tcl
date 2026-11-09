# ser49 (8 Nov, DR013 update 19): stage-5 ECO list, applied on the finished stage-4 route (which reproduces ser48's).
# 13 swaps picked on ser48's own wiring (VPS ser48c_r1.swaps; OpenSTA on gds run 42522293724's unpowered final/nl +
# signoff SDC + min/nom/max SPEF, 9 corners): with them every update-18 term is met at all 9 corners, 0 stuck drivers.
# The in-row fit is on for this stage: ser47/ser48 lost their predicted closure to legalization moving 123/295
# neighbours, so each grown cell takes free sites in its own row instead.
set ::aq_eco_fit 1
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
]
