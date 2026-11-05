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

