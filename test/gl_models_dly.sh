#!/bin/bash
# Gate-level test only: a copy of the GF180 standard-cell models in which every sequential cell's output has a 1 ns delay.
#
# WHY. The gf180mcu_fd_sc_mcu7t5v0 Verilog models are ZERO-DELAY (their UNIT_DELAY macro is never used). This part clocks
# most of its storage from clock gates and latches, so in a zero-delay netlist simulation a flop on a gated clock samples
# the data that a flop on the root clock launched on the SAME edge: a race of the simulator, not of the silicon
# (ASIC-UCV-dev scripts/vps/race_microtest.sh: 50 of 50 wrong). Real cells have clock-to-Q; this restores it. It is the
# same edit as ASIC-UCV-dev scripts/vps/gf_power_compare.sh DELAY_MODELS=1. Prints the path of the file it writes.
# usage: gl_models_dly.sh MODELS_DIR OUT_FILE
set -euo pipefail
src="$1/gf180mcu_fd_sc_mcu7t5v0.v"; out="$2"
mkdir -p "$(dirname "$out")"
{ echo '`timescale 1ns/1ps'
  sed -E 's/^(\s*)not (MGM_BG_[0-9]+)\( ?(QN?), IQ1 ?\);/\1not #1 \2( \3, IQ1 );/' "$src"; } > "$out"
n=$(grep -c 'not #1 MGM_BG_' "$out" || true)
[ "$n" -gt 0 ] || { echo "gl_models_dly.sh: no sequential output found to delay in $src" >&2; exit 1; }
echo "$out"
