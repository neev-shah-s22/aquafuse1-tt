# ser51 (9 Nov, DR013 update 19): stages 3, 4 and 5 folded into one stage-3 list, applied on the finished stage-2 route
# (which reproduces ser46's). Each post-route stage costs a full global + detailed re-route (35-60 min on GitHub runners);
# ser49 needed 5 h 56 min of the 6 h cap, main 470b42a skipped stage 5 at 263 min and ser50 was cancelled by the cap
# during stage 5's re-route. One stage instead of three saves about 75 min and leaves room for one residue stage.
# Entries, in their old stage order (a later entry for the same instance wins, as it did across stages):
#   ser47's stage 3 (12 swaps + buf_8 on _27526_/ZN, picked on ser46's wiring), ser48's stage 4 (9 swaps + buf_8 on
#   _16973_/ZN, picked on ser47's wiring), ser50's stage 5 (18 swaps: ser49's 13 picked on ser48's wiring + 5 on ser49's).
# These were picked on wirings this build will not have; this build's own wiring is audited before any use.
# In-row fit on, 80 um reach (ser50), so grown cells take free sites in their own row before legalization moves others.
set ::aq_eco_fit 1
set ::aq_eco_fit_um 80.0
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
    {_17020_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_17069_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_25370_ gf180mcu_fd_sc_mcu7t5v0__nand2_2} \
    {_27816_ gf180mcu_fd_sc_mcu7t5v0__aoi221_2} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[21].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[70].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8} \
    {clkbuf_1_1__f__16260_ gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[76].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
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
dict set ::aq_eco_lists buffers [list \
    {_27526_ ZN gf180mcu_fd_sc_mcu7t5v0__buf_8} \
    {_16973_ ZN gf180mcu_fd_sc_mcu7t5v0__buf_8} \
]
