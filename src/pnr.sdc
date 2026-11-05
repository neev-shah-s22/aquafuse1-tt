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

# ser31-eco (4 Nov, DR013 update 19): one stage holding the whole what-if-checked list (WHATIF.md).
set ::aq_eco_stages {all}
# ser32 (4 Nov): ser31-eco failed DPL-0036 on 43 cells at {30 8}; legalization window widened.
set ::aq_eco_max_disp {100 20}
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
    set ::aq_eco_file [file join [file dirname $::env(_SDC_IN)] eco_t5.tcl]
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
        set touched [dict create]
        set nswap 0
        set missing {}
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
        global_connect
        log_cmd detailed_placement -max_displacement $::aq_eco_max_disp
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
        write_db $::env(STEP_DIR)/aquafuse_eco_pre_reroute.odb
        return $nswap
    }

    rename ::detailed_route ::aq_drt_orig
    proc ::detailed_route { args } {
        set r [uplevel 1 [list ::aq_drt_orig {*}$args]]
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

