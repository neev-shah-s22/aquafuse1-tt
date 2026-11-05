# AquaFuse ser17 (DR019, energy). LibreLane's base.sdc (3.0.14) unchanged below this block.
#
# WHY A HOOK IN THE SDC. The routed v25 spent 0.81 uJ of its 4.77 uJ per frame (17%) in 93 clock delay buffers and
# 0.09 uJ in 588 dummy loads, all toggling on every clock. OpenROAD CTS inserts them to balance leaf latencies through the
# gated sub-trees (LatencyBalancer, CTS-0033/36) and cell loads; both are on by default and LibreLane 3.0.14's cts.tcl
# exposes neither -no_insertion_delay nor -dont_use_dummy_load (OpenROAD dcf3613 has both). The CTS step reads this file
# (read_current_odb -> read_sdc, a Tcl source) before it calls clock_tree_synthesis, so the command is wrapped here.
# Steps without CTS (no clock_tree_synthesis command) are untouched. Skew left unbalanced is a hold question for the
# resizer's data-path repair and the DR0110 audit, not a function change.
# ser31 (DR013, idea 2): the storage arrays' write clocks are now one explicit gate per array (aclk, u_ag) and one
# and2 per word and lane (aquafuse_lat_gf u_lg) that drives that lane's 7-20 latch E pins. CTS still builds the
# root clk tree and one tree per aclk (the u_lg A1 pins are its sinks), but is told to SKIP each u_lg OUTPUT net, so
# no clkbuf goes below a lane gate (t5 spent 1,089 clkbuf_2 on word trees and 123 on folded-decode trees). Only
# output pins are taken: the input nets are aclk (which must get its tree) and wsel (data). The mechanism is
# ser18-b's (cts::set_skip_clock_nets on net objects, "CTS skips 567 enable-buffer nets"). Expected count: 824
# (bg 91x4, stem 13x4, b1 39x4, b2 28x6, temporal head 84x1).
if { [llength [info commands ::clock_tree_synthesis]] && ![llength [info commands ::aq_cts_orig]] } {
    rename ::clock_tree_synthesis ::aq_cts_orig
    proc ::clock_tree_synthesis { args } {
        # net OBJECTS straight to the call set_cts_config -skip_nets makes, so bracketed names are never re-parsed as patterns
        set seen [dict create]
        set gates [get_cells -hierarchical *u_lg]
        foreach c $gates {
            foreach p [get_pins -of_objects $c] {
                if { [get_property $p direction] ne "output" } { continue }
                foreach n [get_nets -of_objects $p] { dict set seen [get_full_name $n] $n }
            }
        }
        dict for {name n} $seen { cts::set_skip_clock_nets [sta::sta_to_db_net $n] }
        puts "\[INFO] aquafuse pnr.sdc: CTS skips [dict size $seen] lane-gate nets ([llength $gates] u_lg gates, ser31 expects 824); -no_insertion_delay -dont_use_dummy_load (DR019)"
        if { [dict size $seen] != [llength $gates] } {
            puts "\[WARNING] aquafuse pnr.sdc: lane-gate nets ([dict size $seen]) != lane gates ([llength $gates])"
        }
        uplevel 1 [list ::aq_cts_orig {*}$args -no_insertion_delay -dont_use_dummy_load]
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

