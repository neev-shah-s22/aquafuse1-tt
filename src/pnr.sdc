# AquaFuse ser17 (DR019, energy). LibreLane's base.sdc (3.0.14) unchanged below this block.
#
# WHY A HOOK IN THE SDC. The routed v25 spent 0.81 uJ of its 4.77 uJ per frame (17%) in 93 clock delay buffers and
# 0.09 uJ in 588 dummy loads, all toggling on every clock. OpenROAD CTS inserts them to balance leaf latencies through the
# gated sub-trees (LatencyBalancer, CTS-0033/36) and cell loads; both are on by default and LibreLane 3.0.14's cts.tcl
# exposes neither -no_insertion_delay nor -dont_use_dummy_load (OpenROAD dcf3613 has both). The CTS step reads this file
# (read_current_odb -> read_sdc, a Tcl source) before it calls clock_tree_synthesis, so the command is wrapped here.
# Steps without CTS (no clock_tree_synthesis command) are untouched. Skew left unbalanced is a hold question for the
# resizer's data-path repair and the DR0110 audit, not a function change.
#
# CONTROL-PIN SLEW (gf-C-ser25-u*, 3 Nov 2026, DR013 update 19). Under the update 18 rule every clock, latch-enable, ICG
# and reset pin must stay <= 3.0 ns routed in every corner. ser24-t5 (this branch's base) misses at max_ss on 6,188 pins,
# all driven by clkbuf_2 CTS buffers, clock-gating gates or reset buffers. Neither the CTS knobs (clustering never runs on
# these <= 80-sink nets) nor all-larger clock buffers (ser24-t6, +50,900 um2, unroutable) fix it. The same pre-CTS netlist
# rebuilds the same tree (ser25-c3 = ser24-t5, md5 8da091c1), so the drivers to enlarge were chosen from ser24-t5's routed
# max_ss slews (scripts/vps/gf_slew_dump.sh + s112_cts_upsize.py, target AQ_RESIZE_TARGET below) and are applied right
# after clock_tree_synthesis: "swap" changes a cell's master within its family; "insert" puts a clock buffer at a
# clock-gating gate's output. The CTS step then legalizes (detailed_placement) as usual.
proc ::aq_cts_resize_apply {} {
    if { ![info exists ::aq_cts_resize] } { return }
    set block [ord::get_db_block]
    set db [ord::get_db]
    set byname [dict create]
    foreach inst [$block getInsts] { dict set byname [string map {\\ {}} [$inst getName]] $inst }
    set nswap 0
    set nins 0
    set missing {}
    foreach line [split [string trim $::aq_cts_resize] "\n"] {
        set op [lindex $line 0]
        set name [lindex $line 1]
        if { ![dict exists $byname $name] } { lappend missing $name; continue }
        set inst [dict get $byname $name]
        set master [$db findMaster [lindex $line end]]
        if { $master eq "NULL" || $master eq "" } { error "aquafuse pnr.sdc: no master [lindex $line end]" }
        if { $op eq "swap" } {
            if { ![$inst swapMaster $master] } { error "aquafuse pnr.sdc: swapMaster failed on $name" }
            incr nswap
        } elseif { $op eq "insert" } {
            set it [$inst findITerm [lindex $line 2]]
            set net [$it getNet]
            incr nins
            set mid [odb::dbNet_create $block "aq_ctsroot_net_$nins"]
            set buf [odb::dbInst_create $block $master "aq_ctsroot_buf_$nins"]
            $it disconnect
            $it connect $mid
            [$buf findITerm I] connect $mid
            [$buf findITerm Z] connect $net
            set loc [$inst getLocation]
            $buf setLocation [lindex $loc 0] [lindex $loc 1]
            $buf setPlacementStatus PLACED
        } else {
            error "aquafuse pnr.sdc: bad resize line: $line"
        }
    }
    puts "\[INFO] aquafuse pnr.sdc: CTS resize target $::aq_resize_target ns: $nswap swapped, $nins buffers inserted,\
          [llength $missing] not present at CTS: $missing (DR013 update 19)"
    if { [llength $missing] > 8 } { error "aquafuse pnr.sdc: resize list does not match this layout" }
}
if { [llength [info commands ::clock_tree_synthesis]] && ![llength [info commands ::aq_cts_orig]] } {
    rename ::clock_tree_synthesis ::aq_cts_orig
    proc ::clock_tree_synthesis { args } {
        puts "\[INFO] aquafuse pnr.sdc: clock_tree_synthesis -no_insertion_delay -dont_use_dummy_load (DR019)"
        set r [uplevel 1 [list ::aq_cts_orig {*}$args -no_insertion_delay -dont_use_dummy_load]]
        ::aq_cts_resize_apply
        return $r
    }
}
set ::aq_resize_target 2.0
# 965 swaps, 4 inserts: s112_cts_upsize.py --target 2.0 on ser24-t5's routed max_ss_125C_3v00 (VPS vps-074593ae)
set ::aq_cts_resize {
swap _16797_ gf180mcu_fd_sc_mcu7t5v0__nand3_2
swap _16801_ gf180mcu_fd_sc_mcu7t5v0__nand3_2
swap _16802_ gf180mcu_fd_sc_mcu7t5v0__nor3_2
swap _16804_ gf180mcu_fd_sc_mcu7t5v0__nor3_2
swap _16808_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16809_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16813_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16815_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16861_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16903_ gf180mcu_fd_sc_mcu7t5v0__nand2_2
swap _16913_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16915_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16917_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16918_ gf180mcu_fd_sc_mcu7t5v0__nand4_2
swap _16920_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _16921_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16922_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16924_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16930_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16934_ gf180mcu_fd_sc_mcu7t5v0__nand4_2
swap _16936_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16937_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16940_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16941_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16966_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16969_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16978_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _16980_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16984_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16985_ gf180mcu_fd_sc_mcu7t5v0__nand4_2
swap _16986_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16988_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _16990_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _16992_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _16993_ gf180mcu_fd_sc_mcu7t5v0__nand2_2
swap _16997_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _16999_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17001_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17002_ gf180mcu_fd_sc_mcu7t5v0__nand2_2
swap _17003_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _17011_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17013_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17017_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17020_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17023_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17024_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17025_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17026_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17027_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17030_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17031_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17032_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _17033_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17034_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17035_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17036_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _17039_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _17041_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17042_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _17043_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17044_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17045_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17047_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _17050_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17051_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _17052_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _17053_ gf180mcu_fd_sc_mcu7t5v0__nor2_4
swap _17059_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17060_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17062_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17068_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17070_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17071_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17073_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17074_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17076_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17077_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17078_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17079_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17081_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17082_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17083_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17153_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17161_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17163_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17166_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17167_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17168_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17173_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17178_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17179_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17181_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17184_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17186_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17187_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17190_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17193_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17194_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17195_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17197_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17198_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17199_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17200_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17208_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap _17209_ gf180mcu_fd_sc_mcu7t5v0__nor2_2
swap clkbuf_0__00726_ gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_clk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_g_t.u_t.g_slot[2].g_cell[15].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_g_t.u_t.g_slot[2].g_cell[17].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_g_t.u_t.g_slot[2].g_cell[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_g_t.u_t.g_slot[2].g_cell[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_g_t.u_t.hclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[13].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[14].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[15].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[16].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[17].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[18].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[19].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[20].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[21].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[22].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[23].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[24].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[25].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[26].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[27].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[28].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_12
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[29].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[30].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[31].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[32].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_12
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[33].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[34].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[35].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[36].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[37].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[38].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[39].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[40].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[41].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[42].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[43].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[44].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[45].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[46].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[47].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[48].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[49].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[50].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[51].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[52].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[53].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[54].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[55].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[56].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[57].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[58].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[59].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[60].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[61].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[62].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[63].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[64].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[65].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[66].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[67].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[68].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[69].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[70].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[71].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[72].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[73].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[74].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[75].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[76].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[77].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[78].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[79].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[80].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[81].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[82].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[83].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[84].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[85].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[86].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[87].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[88].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[89].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[90].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.g_ent[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_genblk1.g_bg_cell.u_bg.u_uq.gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_b1.cclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b1.g_lane[4].oclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b1.g_lane[5].oclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b1.g_slot[1].g_col[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.cclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[0].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[0].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[0].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[0].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[0].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[0].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[0].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[1].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[1].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[1].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[1].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[1].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[1].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[1].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[2].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[2].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[2].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[2].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[2].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[2].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[2].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[3].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[3].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[3].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[3].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_0_u_b2.g_slot[3].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[3].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.g_slot[3].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_b2.iqclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[10].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[11].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[12].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[1].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[2].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[3].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[4].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[5].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[6].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[7].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[8].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.g_col[9].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_0_u_stem.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_0__f_g_t.u_t.g_slot[2].g_cell[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_g_t.u_t.g_slot[2].g_cell[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b1.g_lane[0].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_lane[1].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_lane[2].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b1.g_lane[3].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b1.g_lane[4].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b1.g_lane[5].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_0__f_u_b1.g_slot[0].g_col[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[1].g_col[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.g_slot[2].g_col[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_0__f_u_b1.iqclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b2.g_lane[0].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_0__f_u_b2.g_lane[1].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_g_t.u_t.g_slot[2].g_cell[14].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b1.g_lane[0].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b1.g_lane[4].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b1.g_lane[5].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b1.g_lane[5].oclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[0].g_col[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.g_slot[1].g_col[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.g_slot[2].g_col[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_1_1__f_u_b1.iqclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b2.g_lane[2].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b2.g_lane[3].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b2.g_lane[4].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_1_1__f_u_b2.g_lane[5].aclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0_0_genblk1.g_bg_cell.u_bg.g_ent[17].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0_0_genblk1.g_bg_cell.u_bg.g_ent[26].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_clk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[13].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[14].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[15].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[16].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[18].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[19].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[20].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[21].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[22].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[23].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[24].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[25].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[27].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[28].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[29].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[30].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[31].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[32].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[33].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[34].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[35].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[36].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[37].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[38].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[39].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[40].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[41].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[42].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[43].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[44].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[45].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[46].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[47].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[48].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[49].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[50].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[51].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[52].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[53].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[54].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[55].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[56].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[57].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[58].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[59].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[60].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[61].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[62].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[63].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[64].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[65].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[66].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[67].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[68].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[69].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[70].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[71].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[72].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[73].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[74].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[75].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[76].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[77].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[78].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[79].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[80].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[81].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[82].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[83].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[84].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[85].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[86].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[87].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[88].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[89].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[90].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.g_ent[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_genblk1.g_bg_cell.u_bg.u_uq.gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_u_b1.cclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_u_b2.cclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[0].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[0].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[0].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[0].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[0].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[0].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[0].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[1].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[1].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[1].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[1].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[1].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[1].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[1].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_u_b2.g_slot[2].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[2].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[2].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[2].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[2].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_u_b2.g_slot[2].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_u_b2.g_slot[2].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[3].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[3].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_u_b2.g_slot[3].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[3].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_u_b2.g_slot[3].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_u_b2.g_slot[3].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.g_slot[3].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_0__f_u_b2.iqclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_0__f_u_sensor.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1_0_genblk1.g_bg_cell.u_bg.g_ent[17].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1_0_genblk1.g_bg_cell.u_bg.g_ent[26].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_clk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[13].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[14].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[15].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[16].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[18].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[19].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[20].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[21].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[22].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[23].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[24].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[25].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[27].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[28].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[29].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[30].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[31].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[32].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[33].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[34].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[35].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[36].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[37].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[38].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[39].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[40].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[41].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[42].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[43].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[44].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[45].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[46].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[47].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[48].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[49].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[50].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[51].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[52].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[53].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[54].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[55].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[56].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[57].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[58].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[59].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[60].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[61].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[62].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[63].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[64].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[65].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[66].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[67].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[68].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[69].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[70].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[71].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[72].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[73].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[74].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[75].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[76].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[77].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[78].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[79].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[80].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[81].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[82].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[83].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[84].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[85].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[86].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[87].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[88].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[89].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[90].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.g_ent[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_genblk1.g_bg_cell.u_bg.u_uq.gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b1.cclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.cclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[0].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[0].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[0].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[0].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[0].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[0].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[0].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[1].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[1].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[1].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[1].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[1].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[1].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[1].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[2].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[2].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[2].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[2].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[2].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[2].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[2].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[3].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[3].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[3].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_1__f_u_b2.g_slot[3].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[3].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[3].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_1__f_u_b2.g_slot[3].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2_0_genblk1.g_bg_cell.u_bg.g_ent[17].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2_0_genblk1.g_bg_cell.u_bg.g_ent[26].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_clk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[13].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[14].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[15].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[16].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[18].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[19].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[20].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[21].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[22].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[23].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[24].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[25].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[27].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[28].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[29].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[30].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[31].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[32].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[33].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[34].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[35].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[36].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[37].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[38].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[39].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[40].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[41].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[42].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[43].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[44].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[45].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[46].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[47].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[48].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[49].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[50].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[51].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[52].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[53].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[54].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[55].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[56].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[57].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[58].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[59].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[60].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[61].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[62].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[63].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[64].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[65].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[66].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[67].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[68].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[69].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[70].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[71].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[72].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[73].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[74].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[75].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[76].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[77].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[78].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[79].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[80].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[81].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[82].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[83].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[84].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[85].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[86].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[87].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[88].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[89].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[90].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.g_ent[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_genblk1.g_bg_cell.u_bg.u_uq.gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_u_b1.cclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.cclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_u_b2.g_slot[0].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[0].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[0].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_u_b2.g_slot[0].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[0].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_u_b2.g_slot[0].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[0].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[1].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[1].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[1].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_u_b2.g_slot[1].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[1].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[1].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[1].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[2].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[2].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[2].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_2__f_u_b2.g_slot[2].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[2].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[2].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[2].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[3].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[3].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[3].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[3].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[3].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[3].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.g_slot[3].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_b2.iqclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_2__f_u_sensor.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3_0_genblk1.g_bg_cell.u_bg.g_ent[17].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3_0_genblk1.g_bg_cell.u_bg.g_ent[26].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_clk gf180mcu_fd_sc_mcu7t5v0__clkbuf_12
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[10].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[11].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[12].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[13].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[14].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[15].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[16].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[18].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[19].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[20].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[21].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[22].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[23].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[24].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[25].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[27].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[28].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[29].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[30].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[31].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[32].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[33].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[34].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[35].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[36].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[37].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[38].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[39].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[40].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[41].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[42].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[43].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[44].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[45].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[46].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[47].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[48].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[49].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[50].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[51].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[52].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[53].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[54].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[55].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[56].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[57].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[58].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[59].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[60].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[61].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[62].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[63].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[64].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[65].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[66].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[67].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[68].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[69].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[70].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[71].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[72].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[73].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[74].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[75].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[76].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[77].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[78].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[79].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[7].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[80].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[81].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[82].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[84].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[85].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[86].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[87].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[88].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[89].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[8].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[90].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.g_ent[9].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
swap clkbuf_2_3__f_genblk1.g_bg_cell.u_bg.u_uq.gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_u_b1.cclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.cclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_u_b2.g_slot[0].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[0].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[0].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_u_b2.g_slot[0].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[0].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_u_b2.g_slot[0].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[0].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_u_b2.g_slot[1].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[1].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[1].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[1].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_u_b2.g_slot[1].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[1].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[1].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[2].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[2].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[2].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[2].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[2].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[2].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[2].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[3].g_col[0].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_u_b2.g_slot[3].g_col[1].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[3].g_col[2].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_u_b2.g_slot[3].g_col[3].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[3].g_col[4].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[3].g_col[5].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_b2.g_slot[3].g_col[6].gclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_2_3__f_u_b2.iqclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_2_3__f_u_sensor.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[10].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[11].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_0_0_u_stem.g_col[12].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[1].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[2].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[3].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_0_0_u_stem.g_col[4].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[5].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[6].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[7].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[8].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.g_col[9].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0_0_u_stem.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_0__f_g_t.u_t.hclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_1_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_1_0_u_stem.g_col[10].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_1_0_u_stem.g_col[11].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_1_0_u_stem.g_col[12].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_1_0_u_stem.g_col[1].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_1_0_u_stem.g_col[2].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_1_0_u_stem.g_col[3].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_1_0_u_stem.g_col[4].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_1_0_u_stem.g_col[5].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_1_0_u_stem.g_col[6].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_1_0_u_stem.g_col[7].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_1_0_u_stem.g_col[8].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_1_0_u_stem.g_col[9].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_1_0_u_stem.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_2_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_2_0_u_stem.g_col[10].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_2_0_u_stem.g_col[11].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_2_0_u_stem.g_col[12].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_2_0_u_stem.g_col[1].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_2_0_u_stem.g_col[2].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_2_0_u_stem.g_col[3].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_2_0_u_stem.g_col[4].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_2_0_u_stem.g_col[5].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_2_0_u_stem.g_col[6].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_2_0_u_stem.g_col[7].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_2_0_u_stem.g_col[8].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_2_0_u_stem.g_col[9].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_2_0_u_stem.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_3_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_3_0_u_stem.g_col[10].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_3_0_u_stem.g_col[11].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_3_0_u_stem.g_col[12].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_3_0_u_stem.g_col[1].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_3_0_u_stem.g_col[2].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_3_0_u_stem.g_col[3].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_3_0_u_stem.g_col[4].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_3_0_u_stem.g_col[5].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_3_0_u_stem.g_col[6].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_3_0_u_stem.g_col[7].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_3_0_u_stem.g_col[8].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_3_0_u_stem.g_col[9].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_3_0_u_stem.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_4_0_u_stem.g_col[10].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.g_col[11].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.g_col[12].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_4_0_u_stem.g_col[1].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_4_0_u_stem.g_col[2].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.g_col[3].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.g_col[4].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.g_col[5].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.g_col[6].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.g_col[7].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.g_col[8].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.g_col[9].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_4_0_u_stem.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[10].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[11].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[12].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[1].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[2].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[3].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[4].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[5].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[6].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_5_0_u_stem.g_col[7].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_5_0_u_stem.g_col[8].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.g_col[9].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_5_0_u_stem.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[10].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[11].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[12].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[1].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[2].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[3].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[4].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[5].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[6].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[7].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[8].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6_0_u_stem.g_col[9].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_6__f_g_t.u_t.hclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_7_0_u_stem.g_col[0].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_7_0_u_stem.g_col[10].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_7_0_u_stem.g_col[11].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_7_0_u_stem.g_col[12].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_7_0_u_stem.g_col[1].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_7_0_u_stem.g_col[2].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_7_0_u_stem.g_col[3].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_7_0_u_stem.g_col[4].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_7_0_u_stem.g_col[5].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_7_0_u_stem.g_col[6].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap clkbuf_3_7_0_u_stem.g_col[7].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_7_0_u_stem.g_col[8].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_7_0_u_stem.g_col[9].u_lat.en gf180mcu_fd_sc_mcu7t5v0__clkbuf_4
swap clkbuf_3_7_0_u_stem.sclk gf180mcu_fd_sc_mcu7t5v0__clkbuf_3
swap fanout895 gf180mcu_fd_sc_mcu7t5v0__buf_2
swap fanout901 gf180mcu_fd_sc_mcu7t5v0__buf_3
swap fanout905 gf180mcu_fd_sc_mcu7t5v0__buf_3
swap fanout910 gf180mcu_fd_sc_mcu7t5v0__buf_2
insert _16800_ ZN gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
insert _16994_ ZN gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
insert _17029_ ZN gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
insert _17046_ ZN gf180mcu_fd_sc_mcu7t5v0__clkbuf_8
}

set clock_port __VIRTUAL_CLK__
if { [info exists ::env(CLOCK_PORT)] } {
    set port_count [llength $::env(CLOCK_PORT)]

    if { $port_count == "0" } {
        puts "\[WARNING] No CLOCK_PORT found. A dummy clock will be used."
    } elseif { $port_count != "1" } {
        puts "\[WARNING] Multi-clock files are not currently supported by the base SDC file. Only the first clock will be constrained."
    }

    if { $port_count > "0" } {
        set ::clock_port [lindex $::env(CLOCK_PORT) 0]
    }
}
set port_args [get_ports $clock_port]
puts "\[INFO] Using clock $clock_port…"
create_clock {*}$port_args -name $clock_port -period $::env(CLOCK_PERIOD)

set input_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
set output_delay_value [expr $::env(CLOCK_PERIOD) * $::env(IO_DELAY_CONSTRAINT) / 100]
puts "\[INFO] Setting output delay to: $output_delay_value"
puts "\[INFO] Setting input delay to: $input_delay_value"

set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    set_max_transition $::env(MAX_TRANSITION_CONSTRAINT) [current_design]
}
if { [info exists ::env(MAX_CAPACITANCE_CONSTRAINT)] } {
    set_max_capacitance $::env(MAX_CAPACITANCE_CONSTRAINT) [current_design]
} 
# gf-C-ser24-t2 (2 Nov ~6 PM PST, DR013 update 17): DR0110 Tier 2 (owner, 27 Oct) blocks on each pin's own Liberty limit with >= 10 %
# headroom (GF180 7t: max_transition 15.6 ns per pin, per-cell max_capacitance). Repairing every net to the 3 ns / 0.2 pF
# design target needs ~1,000+ more buffers than the 78.8 %-full 4x4 core routes (ser21/ser22/ser23-g2..g6). So the
# repair steps only use the limits below; CTS and signoff STA keep 3 ns / 0.2 pF, which stay published as design targets.
if { [info exists ::env(STEP_DIR)] && [regexp -nocase {(repairdesign|resizertiming)} [file tail $::env(STEP_DIR)]] } {
    set_max_transition 6.0 [current_design]
    set_max_capacitance 0.25 [current_design]
    puts "\[INFO] aquafuse pnr.sdc: repair limits 6.0 ns / 0.25 pF in [file tail $::env(STEP_DIR)] (DR0110 Tier 2)"
}

set clk_input [get_port $clock_port]
set clk_indx [lsearch [all_inputs] $clk_input]
set all_inputs_wo_clk [lreplace [all_inputs] $clk_indx $clk_indx ""]

#set rst_input [get_port resetn]
#set rst_indx [lsearch [all_inputs] $rst_input]
#set all_inputs_wo_clk_rst [lreplace $all_inputs_wo_clk $rst_indx $rst_indx ""]
set all_inputs_wo_clk_rst $all_inputs_wo_clk

# correct resetn
set clocks [get_clocks $clock_port]

set_input_delay $input_delay_value -clock $clocks $all_inputs_wo_clk_rst
set_output_delay $output_delay_value -clock $clocks [all_outputs]

if { ![info exists ::env(SYNTH_CLK_DRIVING_CELL)] } {
    set ::env(SYNTH_CLK_DRIVING_CELL) $::env(SYNTH_DRIVING_CELL)
}

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_DRIVING_CELL) "/"] 1] \
    $all_inputs_wo_clk_rst

set_driving_cell \
    -lib_cell [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 0] \
    -pin [lindex [split $::env(SYNTH_CLK_DRIVING_CELL) "/"] 1] \
    $clk_input

set cap_load [expr $::env(OUTPUT_CAP_LOAD) / 1000.0]
puts "\[INFO] Setting load to: $cap_load"
set_load $cap_load [all_outputs]

puts "\[INFO] Setting clock uncertainty to: $::env(CLOCK_UNCERTAINTY_CONSTRAINT)"
set_clock_uncertainty $::env(CLOCK_UNCERTAINTY_CONSTRAINT) $clocks

puts "\[INFO] Setting clock transition to: $::env(CLOCK_TRANSITION_CONSTRAINT)"
set_clock_transition $::env(CLOCK_TRANSITION_CONSTRAINT) $clocks

puts "\[INFO] Setting timing derate to: $::env(TIME_DERATING_CONSTRAINT)%"
set_timing_derate -early [expr 1-[expr $::env(TIME_DERATING_CONSTRAINT) / 100.0]]
set_timing_derate -late [expr 1+[expr $::env(TIME_DERATING_CONSTRAINT) / 100.0]]

if { [info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS) } {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}

