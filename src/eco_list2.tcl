# ser53 (10 Nov, DR013 update 19): ser52 plus 76 swaps picked on ser52's own wiring (VPS ser52gh_h1.swaps, gds run
# 42665224772 final/nl + signoff SDC + min/nom/max SPEF, 9 corners) against a guard band: every control and data pin
# held under 0.90 x its limit (eco_pick_guard.py), then the hold chain (eco_hold_pick.py, 6 capture-clock upsizes).
# On ser52's wiring all update-18 terms are met with them (tt control 0, data 0, hold >= +0.1876 ns, latch 0).
# The guard is there so the re-route this fold causes stays under the limits. Appended last (later entries win).
# ser52 (9 Nov, DR013 update 19): stages 2-5 folded into one stage-2 list, applied on the finished first route (stage 1,
# unchanged). Each post-route stage costs a full global + detailed re-route (35-60 min on GitHub runners); ser49 needed
# 5 h 56 min of the 6 h cap, main 470b42a skipped stage 5 at 263 min and ser50 was cancelled by the cap during stage 5.
# One post-route stage instead of four saves about 2 h. Run beside ser51 (stages 3-5 folded, stage 2 kept).
# Entries, in their old stage order (a later entry for the same instance wins, as it did across stages):
#   ser46's stage 2 (43 swaps, picked on ser42/ser44 wiring), ser47's stage 3 (12 + buf_8 on _27526_/ZN), ser48's
#   stage 4 (9 + buf_8 on _16973_/ZN), ser50's stage 5 (18).
# These were picked on wirings this build will not have; this build's own wiring is audited before any use.
# In-row fit on, 80 um reach (ser50), so grown cells take free sites in their own row before legalization moves others.
set ::aq_eco_fit 1
set ::aq_eco_fit_um 80.0
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
    {_16997_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_17082_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_17198_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_19015_ gf180mcu_fd_sc_mcu7t5v0__xor2_2} \
    {_20141_ gf180mcu_fd_sc_mcu7t5v0__aoi22_2} \
    {_25421_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_27238_ gf180mcu_fd_sc_mcu7t5v0__xor2_2} \
    {_27379_ gf180mcu_fd_sc_mcu7t5v0__aoi21_2} \
    {_27528_ gf180mcu_fd_sc_mcu7t5v0__nor3_2} \
    {_28098_ gf180mcu_fd_sc_mcu7t5v0__oai211_4} \
    {_28853_ gf180mcu_fd_sc_mcu7t5v0__nor3_2} \
    {_29471_ gf180mcu_fd_sc_mcu7t5v0__nor4_2} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[68].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[89].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8} \
    {clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[47].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
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
    {_16745_ gf180mcu_fd_sc_mcu7t5v0__xnor2_2} \
    {_16755_ gf180mcu_fd_sc_mcu7t5v0__xor2_2} \
    {_16829_ gf180mcu_fd_sc_mcu7t5v0__nand2_2} \
    {_16831_ gf180mcu_fd_sc_mcu7t5v0__nand3_2} \
    {_16882_ gf180mcu_fd_sc_mcu7t5v0__and3_4} \
    {_16912_ gf180mcu_fd_sc_mcu7t5v0__or3_2} \
    {_16939_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_16971_ gf180mcu_fd_sc_mcu7t5v0__nand2_2} \
    {_16994_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_17005_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_17020_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_17088_ gf180mcu_fd_sc_mcu7t5v0__nand2_2} \
    {_17110_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_17148_ gf180mcu_fd_sc_mcu7t5v0__nand2_2} \
    {_17185_ gf180mcu_fd_sc_mcu7t5v0__or3_2} \
    {_17450_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_19997_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_20235_ gf180mcu_fd_sc_mcu7t5v0__nor4_2} \
    {_20236_ gf180mcu_fd_sc_mcu7t5v0__or4_2} \
    {_20632_ gf180mcu_fd_sc_mcu7t5v0__nand4_2} \
    {_20922_ gf180mcu_fd_sc_mcu7t5v0__oai32_2} \
    {_20937_ gf180mcu_fd_sc_mcu7t5v0__nand4_2} \
    {_21191_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_21291_ gf180mcu_fd_sc_mcu7t5v0__or2_2} \
    {_21901_ gf180mcu_fd_sc_mcu7t5v0__oai21_2} \
    {_22161_ gf180mcu_fd_sc_mcu7t5v0__nor3_2} \
    {_23993_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_24140_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_25412_ gf180mcu_fd_sc_mcu7t5v0__nand2_2} \
    {_25445_ gf180mcu_fd_sc_mcu7t5v0__nand2_2} \
    {_25465_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_25486_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_25489_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_25502_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_25503_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_25506_ gf180mcu_fd_sc_mcu7t5v0__nor2_4} \
    {_25575_ gf180mcu_fd_sc_mcu7t5v0__aoi221_2} \
    {_26023_ gf180mcu_fd_sc_mcu7t5v0__nor3_2} \
    {_26435_ gf180mcu_fd_sc_mcu7t5v0__aoi222_2} \
    {_26445_ gf180mcu_fd_sc_mcu7t5v0__nor3_2} \
    {_27261_ gf180mcu_fd_sc_mcu7t5v0__oai21_2} \
    {_27368_ gf180mcu_fd_sc_mcu7t5v0__nor2_2} \
    {_28167_ gf180mcu_fd_sc_mcu7t5v0__aoi21_2} \
    {_28172_ gf180mcu_fd_sc_mcu7t5v0__aoi21_2} \
    {_28177_ gf180mcu_fd_sc_mcu7t5v0__aoi21_2} \
    {_29053_ gf180mcu_fd_sc_mcu7t5v0__aoi21_2} \
    {_29386_ gf180mcu_fd_sc_mcu7t5v0__nor4_2} \
    {_29391_ gf180mcu_fd_sc_mcu7t5v0__nor4_2} \
    {_29414_ gf180mcu_fd_sc_mcu7t5v0__nand3_2} \
    {_29480_ gf180mcu_fd_sc_mcu7t5v0__nor4_2} \
    {_29583_ gf180mcu_fd_sc_mcu7t5v0__nand4_2} \
    {_30109_ gf180mcu_fd_sc_mcu7t5v0__nor4_4} \
    {_32058_ gf180mcu_fd_sc_mcu7t5v0__xnor2_2} \
    {_33088_ gf180mcu_fd_sc_mcu7t5v0__dffq_2} \
    {_33135_ gf180mcu_fd_sc_mcu7t5v0__dffrnq_2} \
    {_33508_ gf180mcu_fd_sc_mcu7t5v0__dffrnq_2} \
    {_33913_ gf180mcu_fd_sc_mcu7t5v0__buf_2} \
    {clkbuf_0__00686_ gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {clkbuf_0__00727_ gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[16].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[18].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[66].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[87].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[90].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_0_u_stem.g_col[3].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_1_1__f__00686_ gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {clkbuf_1_1__f__00727_ gf180mcu_fd_sc_mcu7t5v0__clkbuf_4} \
    {clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[37].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[63].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[42].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[57].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[69].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3} \
    {fanout901 gf180mcu_fd_sc_mcu7t5v0__buf_2} \
]
dict set ::aq_eco_lists buffers [list \
    {_27526_ ZN gf180mcu_fd_sc_mcu7t5v0__buf_8} \
    {_16973_ ZN gf180mcu_fd_sc_mcu7t5v0__buf_8} \
]
