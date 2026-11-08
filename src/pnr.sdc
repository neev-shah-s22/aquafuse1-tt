# AquaFuse ser17 (DR019, energy). LibreLane's base.sdc (3.0.14) unchanged below this block.
#
# WHY A HOOK IN THE SDC. The routed v25 spent 0.81 uJ of its 4.77 uJ per frame (17%) in 93 clock delay buffers and
# 0.09 uJ in 588 dummy loads, all toggling on every clock. OpenROAD CTS inserts them to balance leaf latencies through the
# gated sub-trees (LatencyBalancer, CTS-0033/36) and cell loads; both are on by default and LibreLane 3.0.14's cts.tcl
# exposes neither -no_insertion_delay nor -dont_use_dummy_load (OpenROAD dcf3613 has both). The CTS step reads this file
# (read_current_odb -> read_sdc, a Tcl source) before it calls clock_tree_synthesis, so the command is wrapped here.
# Steps without CTS (no clock_tree_synthesis command) are untouched. Skew left unbalanced is a hold question for the
# resizer's data-path repair and the DR0110 audit, not a function change.
if { [llength [info commands ::clock_tree_synthesis]] && ![llength [info commands ::aq_cts_orig]] } {
    rename ::clock_tree_synthesis ::aq_cts_orig
    proc ::clock_tree_synthesis { args } {
        puts "\[INFO] aquafuse pnr.sdc: clock_tree_synthesis -no_insertion_delay -dont_use_dummy_load (DR019)"
        uplevel 1 [list ::aq_cts_orig {*}$args -no_insertion_delay -dont_use_dummy_load]
    }
}

# ser36 (5 Nov, DR013 update 19, IDEAS2.md idea 2): ECO-ready draw. Every post-route ECO on t5 failed for room: its 138
# upsizes sit in 91 %-full latch-array rows, so legalization moved ~1,400 cells and the re-route never converged (ECO
# lab 1-3). Here every detailed_placement first gives the cells that ECO upsizes free sites on their right
# (dpl::set_padding_inst, held in DPL's memory only, hence re-applied in every step). The routed layout then keeps those
# sites empty, and a post-route swap can grow into them in place, the way the DRT antenna diodes did.
#   ::aq_pad_names   instance -> sites (src/eco_pad_names.tcl: r11's width delta per upsized cell)
#   ::aq_pad_root    sites for every gated-clock root clkbuf_0_* (r11 grows 71 of the 340 by 5-6 sites)
#   ::aq_pad_driver  sites for the cell driving each root's input (the word gating gate)
#   ::aq_pad_leaf    sites for every clkbuf_<n>_<m>__f_* leaf buffer
if { ![info exists ::aq_pad_root] } { set ::aq_pad_root 6 }
if { ![info exists ::aq_pad_driver] } { set ::aq_pad_driver 4 }
if { ![info exists ::aq_pad_leaf] } { set ::aq_pad_leaf 3 }
if { [llength [info commands ::detailed_placement]] && ![llength [info commands ::aq_dpl_orig]]
     && [llength [info commands ::dpl::set_padding_inst]] && [info exists ::env(_SDC_IN)] } {
    set ::aq_pad_file [file join [file dirname $::env(_SDC_IN)] eco_pad_names.tcl]
    if { [file exists $::aq_pad_file] } { source $::aq_pad_file } else { set ::aq_pad_names [dict create] }
    proc ::aq_pad_apply {} {
        # ser37: the DetailedRouting step's ECO consumes the padding; legalizing there must not re-open it
        if { [info exists ::env(STEP_DIR)] && [regexp -nocase {detailedrouting} [file tail $::env(STEP_DIR)]] } {
            puts "\[INFO] aquafuse pnr.sdc: ECO-ready padding off in [file tail $::env(STEP_DIR)] (ser37)"
            return
        }
        set block [ord::get_db_block]
        set pad [dict create]
        foreach inst [$block getInsts] {
            set name [string map {\\ {}} [$inst getName]]
            set p 0
            if { [dict exists $::aq_pad_names $name] } { set p [dict get $::aq_pad_names $name] }
            if { [string match {clkbuf_0_*} $name] } {
                set p [expr { max($p, $::aq_pad_root) }]
                set it [$inst findITerm I]
                if { $it ne "NULL" && $it ne "" && [$it getNet] ne "NULL" } {
                    foreach d [[$it getNet] getITerms] {
                        if { [$d isOutputSignal] } {
                            set dn [$d getInst]
                            set q [expr { [dict exists $pad $dn] ? [lindex [dict get $pad $dn] 1] : 0 }]
                            dict set pad $dn [list $dn [expr { max($q, $::aq_pad_driver) }]]
                        }
                    }
                }
            } elseif { [regexp {^clkbuf_[0-9]+_[0-9]+__f_} $name] } {
                set p [expr { max($p, $::aq_pad_leaf) }]
            }
            if { $p > 0 } {
                set q [expr { [dict exists $pad $inst] ? [lindex [dict get $pad $inst] 1] : 0 }]
                dict set pad $inst [list $inst [expr { max($p, $q) }]]
            }
        }
        set sites 0
        dict for {k v} $pad {
            lassign $v inst p
            if { [[$inst getMaster] isFiller] || [$inst isFixed] } { continue }
            dpl::set_padding_inst $inst 0 $p
            incr sites $p
        }
        puts "\[INFO] aquafuse pnr.sdc: ECO-ready padding on [dict size $pad] instances, $sites sites\
              (root $::aq_pad_root, driver $::aq_pad_driver, leaf $::aq_pad_leaf; DR013 update 19)"
    }
    rename ::detailed_placement ::aq_dpl_orig
    proc ::detailed_placement { args } {
        ::aq_pad_apply
        return [uplevel 1 [list ::aq_dpl_orig {*}$args]]
    }
}

# ser31-eco (4 Nov, DR013 update 19): one stage holding the whole what-if-checked list (WHATIF.md).
set ::aq_eco_stages {all}
# ser32 (4 Nov): ser31-eco failed DPL-0036 on 43 cells at {30 8}; legalization window widened.
set ::aq_eco_max_disp {300 60}
# ser37 (5 Nov, DR013 update 19, IDEAS2.md idea 2 run B): padB's own what-if swap list (src/eco_list.tcl) applied at the
# start of DetailedRouting, before its single route ("pre": ECO lab 4's zero-swap control routed t5 this way to 0 in
# 40 min). The swapped cells grow into padB's padding and the rest of the room comes from planned exact positions
# (src/eco_moves.tcl, s116 on padB's step-44 DEF: 419 cells, 1.49 mm). One segment (row 760480) has no room within
# 60 um, so detailed_placement still runs, in a small window: on an already legal placement it moves only what overlaps
# (ECO lab 4: 0 cells moved), and padding is off in this step (see aq_pad_apply) so it does not try to re-open the gaps
# the swaps have just used. Global routing is then re-made for the new placement (::aq_eco_regrt full).
set ::aq_eco_mode pre
set ::aq_eco_regrt full
set ::aq_eco_dpl 1
set ::aq_eco_max_disp {100 20}
set ::aq_eco_watch {_16961_ max_cap504 _16970_}
set ::aq_drt_seeds {}
set ::aq_drt_antenna_fresh 1
set ::aq_drt_fresh_n 0
# ser44 (7 Nov): no from-scratch antenna passes. ser43 (identical to ser42 up to the first route) needed 166 min for the
# first route on a slower runner where ser42 took 98, so its fresh antenna passes ran into the 245 min budget and the
# job hit the 6 h cap in FillInsertion. Stage 2 now runs straight on the first route (deterministic across runners)
# and repairs antennas incrementally there (ser43: 17 diodes, re-route 0 in 13 min).
set ::aq_drt_ant_iters 0
set ::aq_eco2_ant_passes 6
set ::aq_drt_ant_margin 10
set ::aq_drt_budget_min 245
set ::aq_drt_reroute_iters 24
if { [info exists ::env(_SDC_IN)] && [file exists [file join [file dirname $::env(_SDC_IN)] eco_moves.tcl]] } {
    source [file join [file dirname $::env(_SDC_IN)] eco_moves.tcl]
}
# ECO lab (5 Nov, DR013 update 19): src/eco_variant.tcl, if present, overrides the settings above for one lab job.
# Lab-only knobs, all optional:
#   ::aq_eco_mode   post (default: route, ECO, re-route) | lab_post (the input ODB is already routed: ECO, re-route) |
#                   pre (ECO first, then the step's single route)
#   ::aq_eco_lock   instances held LOCKED while the ECO legalizes
#   ::aq_eco_watch  instances whose master and location are logged before and after legalization
#   ::aq_eco_moves  {inst x_dbu y_dbu orient} placed before legalization (src/eco_moves.tcl)
#   ::aq_eco_regrt  none (default) | full (re-run global routing after the ECO) | incr (incremental global routing
#                   around the ECO; falls back to full if OpenROAD refuses it in this process)
if { [info exists ::env(_SDC_IN)] && [file exists [file join [file dirname $::env(_SDC_IN)] eco_variant.tcl]] } {
    source [file join [file dirname $::env(_SDC_IN)] eco_variant.tcl]
    puts "\[INFO] aquafuse pnr.sdc: ECO lab variant loaded"
}
# ---------------------------------------------------------------------------------------------------------------------
# AquaFuse post-route ECO (DR013 update 18 / IDEAS.md idea 1). INSERT INTO src/pnr.sdc of codex/gf-C-ser24-t5, anywhere
# before the "set clock_port" line (next to the existing clock_tree_synthesis wrapper). Needs src/eco_t5.tcl beside it.
#
# WHY HERE. Every OpenROAD step sources this file (read_current_odb -> read_current_sdc -> read_sdc), including
# OpenROAD.DetailedRouting (drt.tcl). drt.tcl defines drt_run, which calls `log_cmd detailed_route ...`; log_cmd runs
# `$cmd {*}$args`, so a global proc named detailed_route replaces it. drt.tcl then runs the antenna loop, which calls
# drt_run (so detailed_route) again on the routed database: t5's own log shows that re-route going 556 -> 0 violations in
# 12 min after 11 diodes. This hook uses the same mechanism once, right after the first full route:
#   1. original detailed_route (t5's route, unchanged);
#   2. ONCE (::aq_eco_done): swapMaster from src/eco_t5.tcl (same pins, same nets, no new nets, so every route guide
#      stays valid); global_connect for the new masters' power pins;
#   3. legalize only what overlaps: detailed_placement with a small displacement (no optimize_mirroring, which would
#      move cells that are already legal and routed), check_placement;
#   4. rip up the wires of every net touching a swapped or moved instance, so TritonRoute reconnects their pins
#      instead of leaving stale segments (guides are kept in the ODB from global routing);
#   5. original detailed_route again, with the same arguments (same -output_drc file: the step's DRC report is the
#      post-ECO one). drt.tcl's antenna loop and write_views follow as usual and see the post-ECO design.
# Recursion: the wrapper calls ::aq_drt_orig (the renamed built-in) for both routes, never ::detailed_route, and the
# ECO body is guarded by ::aq_eco_done, so the antenna loop's later drt_run calls are plain re-routes.
# Steps other than DetailedRouting are untouched (STEP_DIR check), and plain OpenSTA steps have no detailed_route.
# ---------------------------------------------------------------------------------------------------------------------
if { [llength [info commands ::detailed_route]] && ![llength [info commands ::aq_drt_orig]]
     && [info exists ::env(STEP_DIR)] && [regexp -nocase {detailedrouting} [file tail $::env(STEP_DIR)]] } {
    set ::aq_eco_done 0
    # _SDC_IN is this file's own path (read_current_sdc reads it); eco_t5.tcl sits beside it in src/.
    set ::aq_eco_file [file join [file dirname $::env(_SDC_IN)] eco_list.tcl]
    if { ![file exists $::aq_eco_file] && [info exists ::env(DESIGN_DIR)] } {
        set ::aq_eco_file [file join $::env(DESIGN_DIR) eco_t5.tcl]
    }
    # Stages to apply, in order. Drop a stage name to split a run (e.g. {hold} alone, then {hold control}).
    if { ![info exists ::aq_eco_stages] } { set ::aq_eco_stages {hold control data} }
    # Legalization window (um). Swaps widen a cell by 1-6 sites; neighbours should move a few sites at most.
    if { ![info exists ::aq_eco_max_disp] } { set ::aq_eco_max_disp {30 8} }
    # 1: delete the wires of nets on swapped/moved cells so TritonRoute reconnects them from their (kept) guides.
    # 0: leave stale wires and rely on TritonRoute's incremental mode, as drt.tcl's own diode re-route does.
    if { ![info exists ::aq_eco_ripup] } { set ::aq_eco_ripup 1 }

    if { ![info exists ::aq_eco_mode] } { set ::aq_eco_mode post }
    if { ![info exists ::aq_eco_regrt] } { set ::aq_eco_regrt none }
    # ECO lab, 5 Nov: every ECO variant routed with t5's global-route guides, which predate the ~1,400 cells that
    # legalization moves; all of them stalled near 5,000 violations and then diverged, where t5's own route reached 0.
    # These re-make the guides with GlobalRouting's settings (common/grt.tcl). The DetailedRouting step's config has no
    # GRT_* variables, so t5's resolved values are the fallback.
    proc ::aq_eco_env { name default } {
        if { [info exists ::env($name)] && $::env($name) ne "" } { return $::env($name) }
        return $default
    }
    proc ::aq_eco_grt_preamble {} {
        if { [info exists ::aq_eco_grt_ready] } { return }
        set ::aq_eco_grt_ready 1
        set lo [::aq_eco_env RT_MIN_LAYER Metal2]
        set hi [::aq_eco_env RT_MAX_LAYER Metal4]
        set clo [::aq_eco_env RT_CLOCK_MIN_LAYER $lo]
        set chi [::aq_eco_env RT_CLOCK_MAX_LAYER $hi]
        set_routing_layers -signal $lo-$hi -clock $clo-$chi
        set_global_routing_layer_adjustment * [::aq_eco_env GRT_ADJUSTMENT 0]
        set names {}
        foreach layer [[[ord::get_db] getTech] getLayers] {
            if { [$layer getRoutingLevel] >= 1 } { lappend names [$layer getName] }
        }
        set i 0
        foreach adj [::aq_eco_env GRT_LAYER_ADJUSTMENTS {0 0.3 0.2 0 0}] {
            set_global_routing_layer_adjustment [lindex $names $i] $adj
            incr i
        }
        set_macro_extension [::aq_eco_env GRT_MACRO_EXTENSION 0]
        puts "\[INFO] aquafuse pnr.sdc: ECO global-route settings: layers $lo-$hi, clock $clo-$chi"
    }
    proc ::aq_eco_grt_full {} {
        ::aq_eco_grt_preamble
        log_cmd global_route -congestion_iterations [::aq_eco_env GRT_OVERFLOW_ITERS 15] -verbose -allow_congestion
        puts "\[INFO] aquafuse pnr.sdc: post-route ECO: global routing re-run (full) on the legalized placement"
    }
    proc ::aq_eco_report_watch { tag } {
        if { ![info exists ::aq_eco_watch] } { return }
        set block [ord::get_db_block]
        foreach inst [$block getInsts] {
            if { [string map {\\ {}} [$inst getName]] ni $::aq_eco_watch } { continue }
            puts "\[INFO] aquafuse pnr.sdc: watch $tag [$inst getName] [[$inst getMaster] getName]\
                  [$inst getLocation] [$inst getOrient] [$inst getPlacementStatus]"
        }
    }

    proc ::aq_eco_apply {} {
        set block [ord::get_db_block]
        set db [ord::get_db]
        if { ![file exists $::aq_eco_file] } { error "aquafuse pnr.sdc: post-route ECO list $::aq_eco_file not found" }
        source $::aq_eco_file          ;# defines ::aq_eco_lists: dict stage -> list of {inst master}
        set byname [dict create]
        foreach inst [$block getInsts] { dict set byname [string map {\\ {}} [$inst getName]] $inst }
        # where everything sits before the ECO, to find what legalization moves
        set before [dict create]
        foreach inst [$block getInsts] { dict set before [$inst getName] [$inst getLocation] }
        set orient_before [dict create]
        foreach inst [$block getInsts] { dict set orient_before [$inst getName] [$inst getOrient] }
        set touched [dict create]
        set nswap 0
        set missing {}
        if { $::aq_eco_regrt eq "incr" } {
            ::aq_eco_grt_preamble
            if { [catch { global_route -start_incremental } err] } {
                puts "\[WARNING] aquafuse pnr.sdc: incremental global routing unavailable ($err); using full"
                set ::aq_eco_regrt full
            } else {
                puts "\[INFO] aquafuse pnr.sdc: incremental global routing started before the ECO"
            }
        }
        foreach stage $::aq_eco_stages {
            if { ![dict exists $::aq_eco_lists $stage] } { continue }
            set ns 0
            foreach pair [dict get $::aq_eco_lists $stage] {
                lassign $pair name mname
                if { ![dict exists $byname $name] } { lappend missing $name; continue }
                set inst [dict get $byname $name]
                set master [$db findMaster $mname]
                if { $master eq "NULL" || $master eq "" } { error "aquafuse pnr.sdc: no master $mname" }
                if { [[$inst getMaster] getName] eq $mname } { continue }
                if { ![$inst swapMaster $master] } { error "aquafuse pnr.sdc: swapMaster failed on $name -> $mname" }
                dict set touched [$inst getName] 1
                incr ns
            }
            puts "\[INFO] aquafuse pnr.sdc: post-route ECO stage $stage: $ns swaps"
            incr nswap $ns
        }
        if { [llength $missing] > 0 } {
            puts "\[WARNING] aquafuse pnr.sdc: post-route ECO: [llength $missing] instances not in this layout: [lrange $missing 0 20]"
            if { [llength $missing] > 4 } { error "aquafuse pnr.sdc: ECO list does not match this layout (not t5's route?)" }
        }
        if { [info exists ::aq_eco_moves] } {
            set nm 0
            foreach mv $::aq_eco_moves {
                lassign $mv name x y orient
                if { ![dict exists $byname $name] } { lappend missing $name; continue }
                set inst [dict get $byname $name]
                if { $orient ne "" } { $inst setOrient $orient }
                $inst setLocation $x $y
                $inst setPlacementStatus PLACED
                incr nm
            }
            puts "\[INFO] aquafuse pnr.sdc: post-route ECO: $nm planned moves applied"
        }
        set locked {}
        foreach name [expr { [info exists ::aq_eco_lock] ? $::aq_eco_lock : {} }] {
            if { ![dict exists $byname $name] } { continue }
            set inst [dict get $byname $name]
            lappend locked [list $inst [$inst getPlacementStatus]]
            $inst setPlacementStatus LOCKED
        }
        ::aq_eco_report_watch before
        global_connect
        if { ![info exists ::aq_eco_dpl] || $::aq_eco_dpl } {
            log_cmd detailed_placement -max_displacement $::aq_eco_max_disp
        } else {
            puts "\[INFO] aquafuse pnr.sdc: post-route ECO: no legalization (::aq_eco_dpl 0); planned positions only"
        }
        foreach l $locked { [lindex $l 0] setPlacementStatus [lindex $l 1] }
        # ECO lab, 5 Nov: detailed_placement re-orients cells it does not move (t5's _25381_ R180 -> MX at the same
        # location); their routed wires then miss the mirrored pins (DRT-1231). Put back every original orientation
        # whose row parity is unchanged (same row orientation, so still legal); any other change counts as touched.
        set restored 0
        set reoriented 0
        set rowh [[[lindex [$block getRows] 0] getSite] getHeight]
        foreach inst [$block getInsts] {
            set n [$inst getName]
            if { ![dict exists $orient_before $n] } { continue }
            set o0 [dict get $orient_before $n]
            if { [$inst getOrient] eq $o0 } { continue }
            lassign [dict get $before $n] x0 y0
            lassign [$inst getLocation] x1 y1
            if { (abs($y1 - $y0) / $rowh) % 2 == 0 } {
                $inst setOrient $o0
                $inst setLocation $x1 $y1
                incr restored
            } else {
                dict set touched $n 1
                incr reoriented
            }
        }
        puts "\[INFO] aquafuse pnr.sdc: post-route ECO: $restored orientations restored after legalization,\
              $reoriented cells re-oriented by a row change"
        ::aq_eco_report_watch after
        check_placement -verbose
        set nmoved 0
        set disp 0.0
        set dbu [[$db getTech] getDbUnitsPerMicron]
        foreach inst [$block getInsts] {
            set n [$inst getName]
            if { ![dict exists $before $n] } { continue }
            lassign [dict get $before $n] x0 y0
            lassign [$inst getLocation] x1 y1
            if { $x0 != $x1 || $y0 != $y1 } {
                dict set touched $n 1
                incr nmoved
                set disp [expr {$disp + (abs($x1 - $x0) + abs($y1 - $y0)) / double($dbu)}]
            }
        }
        # rip up the routing of every signal net on a swapped or moved instance (power nets are special nets, kept)
        set ripped [dict create]
        foreach n [expr { $::aq_eco_ripup ? [dict keys $touched] : {} }] {
            set inst [$block findInst $n]
            foreach it [$inst getITerms] {
                set net [$it getNet]
                if { $net eq "NULL" || $net eq "" } { continue }
                if { [$net getSigType] in {POWER GROUND} || [$net isSpecial] } { continue }
                set nn [$net getName]
                if { [dict exists $ripped $nn] } { continue }
                set w [$net getWire]
                if { $w ne "NULL" && $w ne "" } { odb::dbWire_destroy $w }
                dict set ripped $nn 1
            }
        }
        puts "\[INFO] aquafuse pnr.sdc: post-route ECO: $nswap swaps (stages $::aq_eco_stages), $nmoved instances\
              moved by legalization ([format %.1f $disp] um total), [dict size $ripped] nets ripped up for re-route\
              (DR013 update 18, IDEAS.md idea 1)"
        if { $::aq_eco_regrt eq "incr" } {
            if { [catch { global_route -end_incremental -allow_congestion } err] } {
                puts "\[WARNING] aquafuse pnr.sdc: incremental global routing failed to finish ($err); using full"
                ::aq_eco_grt_full
            } else {
                puts "\[INFO] aquafuse pnr.sdc: post-route ECO: incremental global routing re-made the changed guides"
            }
        } elseif { $::aq_eco_regrt eq "full" } {
            ::aq_eco_grt_full
        }
        write_db $::env(STEP_DIR)/aquafuse_eco_pre_reroute.odb
        return $nswap
    }

    rename ::detailed_route ::aq_drt_orig
    proc ::detailed_route { args } {
        if { !$::aq_eco_done && $::aq_eco_mode eq "pre" } {
            set ::aq_eco_done 1
            puts "\[INFO] aquafuse pnr.sdc: ECO lab mode pre: applying the ECO before the first route"
            ::aq_eco_apply
            return [uplevel 1 [list ::aq_drt_orig {*}$args]]
        }
        if { !$::aq_eco_done && $::aq_eco_mode eq "lab_post" } {
            puts "\[INFO] aquafuse pnr.sdc: ECO lab mode lab_post: input ODB is already routed, first route skipped"
            set r 0
        } else {
            set r [uplevel 1 [list ::aq_drt_orig {*}$args]]
        }
        if { !$::aq_eco_done } {
            set ::aq_eco_done 1
            puts "\[INFO] aquafuse pnr.sdc: first detailed route complete; applying post-route ECO from $::aq_eco_file"
            set n [::aq_eco_apply]
            if { $n > 0 } {
                puts "\[INFO] aquafuse pnr.sdc: post-route ECO re-route ($n swaps)"
                set r [uplevel 1 [list ::aq_drt_orig {*}$args]]
            }
        } else {
            puts "\[INFO] aquafuse pnr.sdc: detailed_route passed through (ECO already applied)"
        }
        return $r
    }
    # ser38 (6 Nov, DR013 update 19): ser37's single route reached 0 violations in 34 min, then drt.tcl's antenna loop
    # (8 nets, 10 diodes) re-routed with -or_seed 42 and sat on one Metal4 short from iteration 47 to the 6 h cap; padB's
    # identical loop converged in 2 passes. The first route is unchanged (same seed, so it reproduces ser37's 0); only
    # the antenna loop's re-routes try other seeds, each capped at ::aq_drt_reroute_iters, keeping the first that ends
    # at 0 violations. The last seed gets the step's own -droute_end_iter.
    if { ![info exists ::aq_drt_seeds] } { set ::aq_drt_seeds {} }
    if { ![info exists ::aq_drt_reroute_iters] } { set ::aq_drt_reroute_iters 24 }
    rename ::detailed_route ::aq_drt_eco
    # ser39 (6 Nov): ser38's first route reproduced ser37's 0, but the seeds made the antenna re-route worse (3, then 6,
    # then 7 shorts, each attempt starting from the last one's wires). Every from-scratch route of this placement has
    # converged (lab 4 null control, ser37, ser38), so with ::aq_drt_antenna_fresh the antenna loop's re-routes start
    # from scratch too: the diodes repair_antennas just placed are legalized if needed, every signal wire is removed
    # (the step's input had none: power and special nets are kept), global routing is re-made, and the step's own
    # detailed_route runs with its own arguments.
    if { ![info exists ::aq_drt_antenna_fresh] } { set ::aq_drt_antenna_fresh 0 }
    # ser40 (6 Nov): ser39's four from-scratch routes all reached 0 violations, but each one re-draws every net, so
    # the antenna count wandered (8, 6, 1, then 5 left when drt.tcl's 3 passes ran out; precheck's KLayout antenna
    # check failed with 25). In this step only (config.json's GRT_ANTENNA_REPAIR_MARGIN 0 still governs step 43):
    #   ::aq_drt_ant_iters   replaces DRT_ANTENNA_REPAIR_ITERS (drt.tcl reads it after this file is sourced);
    #   ::aq_drt_ant_margin  replaces repair_antennas' -ratio_margin, so nets near the limit get diodes too and the
    #                        next re-draw is less likely to push them over;
    #   ::aq_drt_budget_min  minutes into the step after which check_antennas reports 0 to end drt.tcl's loop (the
    #                        real count is printed, and OpenROAD.CheckAntennas-1 measures it again after the step),
    #                        so the job finishes inside the 6 h cap with a report instead of being cancelled.
    set ::aq_drt_t0 [clock seconds]
    if { [info exists ::aq_drt_ant_iters] } { set ::env(DRT_ANTENNA_REPAIR_ITERS) $::aq_drt_ant_iters }
    if { [llength [info commands ::check_antennas]] && ![llength [info commands ::aq_ca_orig]] } {
        rename ::check_antennas ::aq_ca_orig
        proc ::check_antennas { args } {
            set n [uplevel 1 [list ::aq_ca_orig {*}$args]]
            set el [expr { ([clock seconds] - $::aq_drt_t0) / 60 }]
            puts "\[INFO] aquafuse pnr.sdc: check_antennas: $n nets, $el min into the step"
            if { $n && [info exists ::aq_drt_budget_min] && $el > $::aq_drt_budget_min } {
                puts "\[WARNING] aquafuse pnr.sdc: antenna loop stopped at the $::aq_drt_budget_min min budget with\
                      $n nets still violating (CheckAntennas-1 reports them)"
                return 0
            }
            return $n
        }
    }
    if { [info exists ::aq_drt_ant_margin] && [llength [info commands ::repair_antennas]]
         && ![llength [info commands ::aq_ra_orig]] } {
        rename ::repair_antennas ::aq_ra_orig
        proc ::repair_antennas { args } {
            set i [lsearch -exact $args -ratio_margin]
            if { $i >= 0 } {
                set args [lreplace $args [expr { $i + 1 }] [expr { $i + 1 }] $::aq_drt_ant_margin]
            } else {
                lappend args -ratio_margin $::aq_drt_ant_margin
            }
            puts "\[INFO] aquafuse pnr.sdc: repair_antennas $args"
            return [uplevel 1 [list ::aq_ra_orig {*}$args]]
        }
    }
    # ser43 (7 Nov): a second, small ECO on the FINISHED route. Each from-scratch route re-draws every net and takes a few
    # new detours (ser42's _10650_: 0.038 pF in ser40, 0.187 pF in ser42), so swap lists picked on one route only partly
    # carry to the next. Everything before write_views is unchanged, so this step reproduces ser42's route exactly (as
    # ser38 reproduced ser37). drt.tcl ends with write_views; just before it, src/eco_list2.tcl (the swaps picked on
    # ser42's own SPEFs) goes through ::aq_eco_apply in post mode with no planned moves: swapMaster, a small
    # detailed_placement, orientation restore, rip-up of only the touched nets, global routing re-made, then an
    # incremental detailed_route of those nets (::aq_eco2_iters iterations) and the antenna check / diode repair on that.
    if { ![info exists ::aq_eco2_iters] } { set ::aq_eco2_iters 40 }
    if { ![info exists ::aq_eco2_ant_passes] } { set ::aq_eco2_ant_passes 3 }
    set ::aq_eco2_done 0
    set ::aq_eco2_file [file join [file dirname $::env(_SDC_IN)] eco_list2.tcl]
    if { [llength [info commands ::write_views]] && ![llength [info commands ::aq_wv_orig]]
         && [file exists $::aq_eco2_file] } {
        rename ::write_views ::aq_wv_orig
        proc ::aq_eco2_route {} {
            set a {}
            set skip 0
            foreach x $::aq_drt_last_args {
                if { $skip } { set skip 0; continue }
                if { $x eq "-droute_end_iter" } { set skip 1; continue }
                lappend a $x
            }
            set r [::aq_drt_orig {*}$a -droute_end_iter $::aq_eco2_iters]
            # as drt.tcl's drt_run does: the step-level DRC report is the latest route's
            set i [lsearch -exact $a -output_drc]
            if { $i >= 0 && [file exists [lindex $a [expr { $i + 1 }]]] } {
                set f [lindex $a [expr { $i + 1 }]]
                file copy -force $f [file join $::env(STEP_DIR) [file tail $f]]
            }
            return $r
        }
        proc ::write_views { args } {
            if { !$::aq_eco2_done } {
                set ::aq_eco2_done 1
                set ::aq_eco_file $::aq_eco2_file
                if { [info exists ::aq_eco_moves] } { unset ::aq_eco_moves }
                set ::aq_eco_mode post
                set ::aq_eco_ripup 1
                set ::aq_eco_regrt full
                set ::aq_eco_dpl 1
                puts "\[INFO] aquafuse pnr.sdc: stage-2 ECO (ser43) on the finished route from $::aq_eco2_file"
                set n [::aq_eco_apply]
                if { $n > 0 } {
                    ::aq_eco2_route
                    set ca [expr { [llength [info commands ::aq_ca_orig]] ? "::aq_ca_orig" : "check_antennas" }]
                    for { set k 1 } { $k <= $::aq_eco2_ant_passes && [$ca] } { incr k } {
                        set diode [lindex [split $::env(DIODE_CELL) "/"] 0]
                        set ra [list $diode -ratio_margin 0]
                        if { [info exists ::env(GRT_ALLOW_CONGESTION)] && $::env(GRT_ALLOW_CONGESTION) } {
                            lappend ra -allow_congestion
                        }
                        set d [repair_antennas {*}$ra]
                        puts "\[INFO] aquafuse pnr.sdc: stage-2 antenna repair $k: $d diodes"
                        if { !$d } { break }
                        ::aq_eco2_route
                    }
                    puts "\[INFO] aquafuse pnr.sdc: stage-2 ECO done ($n swaps)"
                }
            }
            return [uplevel 1 [list ::aq_wv_orig {*}$args]]
        }
    }
    proc ::aq_drt_fresh { args } {
        if { [catch { check_placement } err] } {
            puts "\[INFO] aquafuse pnr.sdc: antenna fresh re-route: placement not legal after diodes ($err); legalizing"
            log_cmd detailed_placement -max_displacement $::aq_eco_max_disp
            check_placement -verbose
        }
        # global routing first (it ignores detailed wires): if OpenROAD refuses a second global_route in this process,
        # the wires are kept and this is drt.tcl's usual incremental re-route
        if { [catch { ::aq_eco_grt_full } err] } {
            puts "\[WARNING] aquafuse pnr.sdc: antenna fresh re-route: global routing failed ($err); incremental re-route"
            return [uplevel 1 [list ::aq_drt_orig {*}$args]]
        }
        set n 0
        foreach net [[ord::get_db_block] getNets] {
            if { [$net getSigType] in {POWER GROUND} || [$net isSpecial] } { continue }
            set w [$net getWire]
            if { $w ne "NULL" && $w ne "" } { odb::dbWire_destroy $w; incr n }
        }
        puts "\[INFO] aquafuse pnr.sdc: antenna fresh re-route: $n signal wires removed after global routing"
        return [uplevel 1 [list ::aq_drt_orig {*}$args]]
    }
    proc ::detailed_route { args } {
        set ::aq_drt_last_args $args
        if { $::aq_eco_done && $::aq_drt_antenna_fresh } {
            incr ::aq_drt_fresh_n
            puts "\[INFO] aquafuse pnr.sdc: antenna re-route $::aq_drt_fresh_n from scratch (ser39)"
            return [uplevel 1 [list ::aq_drt_fresh {*}$args]]
        }
        if { !$::aq_eco_done || ![llength $::aq_drt_seeds] } {
            return [uplevel 1 [list ::aq_drt_eco {*}$args]]
        }
        set base {}
        set end 64
        for { set i 0 } { $i < [llength $args] } { incr i } {
            set a [lindex $args $i]
            if { $a eq "-droute_end_iter" } { incr i; set end [lindex $args $i]; continue }
            if { $a eq "-or_seed" } { incr i; continue }
            lappend base $a
        }
        set seeds $::aq_drt_seeds
        if { ![llength [info commands detailed_route_num_drvs]] } {
            puts "\[WARNING] aquafuse pnr.sdc: no detailed_route_num_drvs; one antenna re-route, seed [lindex $seeds 0]"
            set seeds [lrange $seeds 0 0]
        }
        set k 0
        foreach seed $seeds {
            incr k
            set it [expr { $k == [llength $seeds] ? $end : $::aq_drt_reroute_iters }]
            puts "\[INFO] aquafuse pnr.sdc: antenna re-route attempt $k: -or_seed $seed -droute_end_iter $it"
            set r [uplevel 1 [list ::aq_drt_orig {*}$base -or_seed $seed -droute_end_iter $it]]
            if { [catch { detailed_route_num_drvs } n] } {
                puts "\[WARNING] aquafuse pnr.sdc: detailed_route_num_drvs unavailable ($n); keeping attempt $k"
                return $r
            }
            puts "\[INFO] aquafuse pnr.sdc: antenna re-route attempt $k left $n violations"
            if { $n == 0 } { return $r }
        }
        return $r
    }
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

