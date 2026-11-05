#!/bin/bash
# ser31 RTL respin: the three cheap equivalence checks, in order. VPS ONLY (never on the Mac), one job at a time:
#   nice -n 19 env OMP_NUM_THREADS=2 bash test/ser31/run_equiv.sh [BASE_REF] [PDK_ROOT]
# run from the aquafuse1-tt repo root. BASE_REF defaults to codex/gf-C-ser24-t5 (t5, the routed base).
#   1. BEHAVIOURAL IDENTITY. Every changed file, preprocessed WITHOUT AQUAFUSE_GF180_ICG (what the RTL test, the
#      oracle path and the linter compile), must be token-identical to t5's. Expected: no diff in all 8 files.
#   2. READ PORT, FORMAL. yosys SAT: aquafuse_sel_gf == aquafuse_sel for every input, bg (91x36, 4 lanes) and stem
#      (13x80, 4 lanes). Expected: two "SUCCESS".
#   3. WRITE GATE, SIMULATION. tb_wgate_equiv.sv: t5's GF180 write structure against ser31's, all five arrays,
#      20,000 random cycles, stored bits compared six times per cycle, with the PDK's zero-delay models AND the
#      1 ns clock-to-Q copy that gl_test uses (test/gl_models_dly.sh). Expected: two "WGATE_EQUIV PASS".
# Any FAIL kills the respin until explained (RESPIN.md).
set -euo pipefail
base="${1:-codex/gf-C-ser24-t5}"
pdk_root="${2:-${PDK_ROOT:-$HOME/gf180pdk}}"
models="$pdk_root/gf180mcuD/libs.ref/gf180mcu_fd_sc_mcu7t5v0/verilog"
out="${OUT:-sim_build/ser31_equiv}"
rm -rf "$out"; mkdir -p "$out/old/src" "$out/old/test/compat"
{ date -u +%FT%TZ; hostname; git rev-parse HEAD; echo "base=$base $(git rev-parse "$base")"; } > "$out/conditions.txt"

echo "--- 1. behavioural branch identical to $base (preprocessed, no AQUAFUSE_GF180_ICG) ---"
fail=0
for f in src/aquafuse_wgate.sv src/aquafuse_lat.sv src/aquafuse_sel.sv src/aquafuse_bg_store.sv \
         src/aquafuse_stem_accum.sv src/aquafuse_conv_stage.sv src/aquafuse_temporal_head.sv \
         test/compat/aquafuse_temporal_head.sv; do
    git show "$base:$f" > "$out/old/$f"
    verilator -E -P -Isrc "$out/old/$f" | grep -v '^[[:space:]]*$' > "$out/old.pp"
    verilator -E -P -Isrc "$f"          | grep -v '^[[:space:]]*$' > "$out/new.pp"
    if diff -q "$out/old.pp" "$out/new.pp" >/dev/null; then echo "  identical  $f"
    else echo "  DIFFERENT  $f"; diff "$out/old.pp" "$out/new.pp" | head -20; fail=1; fi
done
[ $fail = 0 ] && echo "BEHAVIOURAL IDENTICAL PASS" || { echo "BEHAVIOURAL IDENTICAL FAIL"; exit 1; }

echo "--- 2. aquafuse_sel_gf == aquafuse_sel (yosys SAT, all inputs) ---"
# the VPS has no yosys on PATH; the gf_* scripts use the yowasp build (scripts/vps/gf_synth_area.sh)
if command -v yosys >/dev/null; then ys=(yosys)
else ys=(env PYTHONPATH=/tmp/yw_inst "$HOME/aquafuse-venv/bin/python" /tmp/yw_inst/bin/yowasp-yosys); fi
"${ys[@]}" -q -l "$out/sel_equiv.log" -s test/ser31/sel_equiv.ys || true     # sat -verify exits non-zero on a counterexample
grep -c "no model found: SUCCESS" "$out/sel_equiv.log" | grep -qx 2 && echo "SEL_EQUIV PASS (2 proofs)" \
    || { echo "SEL_EQUIV FAIL"; tail -30 "$out/sel_equiv.log"; exit 1; }

echo "--- 3. write gate: t5 GF180 structure vs ser31 (Icarus, PDK cell models) ---"
[ -f "$models/gf180mcu_fd_sc_mcu7t5v0.v" ] || { echo "no GF180 models under $models"; exit 1; }
dly=$(bash test/gl_models_dly.sh "$models" "$out/gf180_models_dly.v")
srcs="src/aquafuse_lat.sv src/aquafuse_wgate.sv test/ser31/tb_wgate_equiv.sv"
for m in zero dly; do
    cells="$models/gf180mcu_fd_sc_mcu7t5v0.v"; [ $m = dly ] && cells="$dly"
    iverilog -g2012 -DFUNCTIONAL '-DUNIT_DELAY=#1' -DAQUAFUSE_GF180_ICG -s tb_wgate_equiv -o "$out/wg_$m.vvp" \
        "$models/primitives.v" "$cells" $srcs > "$out/wg_${m}_build.log" 2>&1 \
        || { echo "BUILD FAILED ($m)"; tail -20 "$out/wg_${m}_build.log"; exit 1; }
    vvp "$out/wg_$m.vvp" | tee "$out/wg_$m.log" | grep -E "WGATE_EQUIV|MISMATCH"
    grep -q "WGATE_EQUIV PASS" "$out/wg_$m.log" || { echo "WGATE_EQUIV FAIL ($m models)"; exit 1; }
done
echo "SER31 EQUIV PASS (behavioural identical, 2 SAT proofs, write gate x2 model sets)"
