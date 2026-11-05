`timescale 1ns/1ps
// Write-pulse generator for a word store with NS slots x NC columns: one gated clock per word.
//
// WHY NOT ONE aquafuse_icg PER WORD. An integrated clock gate burns clock-pin energy on every
// cycle whether or not it fires: 242 of them cost ~0.75 mW of GF180 power at 3.3 V, a quarter
// of the whole chip once everything else is gated. This module is the same function with the
// expensive part shared: ONE enable/index latch pair per ARRAY (transparent while clk is low,
// exactly what an ICG's internal latch does), then per word only an AND of clk with the
// decoded, latched index. The AND toggles only on the one word written; the latched index
// cannot change while clk is high, so the gated clock is glitch-free.
//
// gclk[s*NC + c] pulses high during the clk-high phase after a cycle in which en was high and
// (slot, col) == (s, c) -- the same cycle and phase aquafuse_icg gave.
module aquafuse_wgate #(
    parameter int NS = 1,
    parameter int NC = 4,
    parameter int SW = (NS <= 1) ? 1 : $clog2(NS),
    parameter int CW = (NC <= 1) ? 1 : $clog2(NC)
) (
    input  logic                clk,
    input  logic                en,
    input  logic [SW-1:0]       slot,
    input  logic [CW-1:0]       col,
    output logic [NS*NC-1:0]    gclk
);
    wire clk_n = ~clk;
    wire        en_l;
    wire [SW-1:0] slot_l;
    wire [CW-1:0] col_l;
    // ENERGY: a latch whose enable toggles every cycle costs ~4 uW of clock-pin power whether or not it
    // changes. Only the enable latch must follow `en` every cycle (it is the one that says "no write").
    // The slot/column latches are opened (clk low AND en) only in cycles that will write, and hold a stale
    // index otherwise, which is harmless because en_l is then low. `en` is launched by a flop on the
    // rising edge and settles while clk is high, so clk_n & en is a proper clock-gating AND (STA checks it).
    aquafuse_lat #(.W(1)) u_en (.en(clk_n), .d(en), .q(en_l));
    wire iclk_n = clk_n & en;
    aquafuse_lat #(.W(SW + CW)) u_idx (.en(iclk_n), .d({slot, col}), .q({slot_l, col_l}));

    for (genvar s = 0; s < NS; s++) begin : g_s
        wire sel_s = (slot_l == SW'(s));
        for (genvar c = 0; c < NC; c++) begin : g_c
            assign gclk[s*NC + c] = clk & en_l & sel_s & (col_l == CW'(c));
        end
    end
endmodule

`ifdef AQUAFUSE_GF180_ICG
// ser31 (DR013, idea 2): the GF180 write gate, split into ONE explicit clock gate per array and the
// word decode as plain DATA. Used only under AQUAFUSE_GF180_ICG; the behavioural build (the RTL test,
// the oracle path, the linter) keeps aquafuse_wgate above, unchanged.
//
// WHY. aquafuse_wgate writes gclk = clk & en_l & sel_s & (col_l == c) as one expression, and ABC folds
// the clock into the address decode: t5's clock path to bg word 40 is nand4(clk, en_l, ...) -> CTS tree
// -> nor2 -> tree -> nand2 -> tree -> nor2 -> word tree -> 36 latch E. Four gated levels with a CTS tree
// between each (41 of t5's 340 CTS roots, 123 buffers), and the gating check that fails hold (_17030_)
// sits at the bottom of it. Here every cell the clock passes through is INSTANTIATED, so ABC cannot
// restructure it:
//   clk -> u_ag (and2, with the shared enable latch) = aclk, one CTS tree per array
//       -> per word and lane, aquafuse_lat_gf's u_lg (and2 of aclk and wsel[w]) -> the lane's latches
// and wsel[w] = (slot_l == s) & (col_l == c) is ordinary logic from the index latches, so the resizer may
// buffer it and fix hold on it like any data net. src/pnr.sdc tells CTS to skip the u_lg output nets:
// each lane gate drives its 7-20 latches directly.
//
// SAME FUNCTION, CELL FOR CELL. u_en and u_idx are the latches aquafuse_wgate has (same module, same
// enables, same data), so en_l, slot_l and col_l are the same signals. For word w = s*NC + c,
//   aclk & wsel[w] = (clk & en_l) & ((slot_l == s) & (col_l == c)) = aquafuse_wgate's gclk[w],
// and every lane gate of word w computes it. clk_n and iclk_n are aquafuse_wgate's wires, as cells.
//
// GLITCH-FREE. en_l changes only while clk is low (u_en is open on clk_n), so aclk is either a whole clk
// pulse or nothing. slot_l/col_l change only while clk is low and en is high (u_idx is open on
// clk_n & en), and aclk is low whenever clk is low, so wsel's decode settles, glitches included, while
// every lane gate's other input is 0. The two edges are timing checks, not function: wsel must be
// stable before aclk rises (gating setup, ~half a period) and must not move until aclk has fallen
// (gating hold at the leaf, clk-fall -> u_ckn -> u_ien -> u_idx -> decode against clk-fall -> u_ag ->
// aclk tree). STA checks both on the and2 cells, as it checks today's folded gates.
module aquafuse_wgate_gf #(
    parameter int NS = 1,
    parameter int NC = 4,
    parameter int SW = (NS <= 1) ? 1 : $clog2(NS),
    parameter int CW = (NC <= 1) ? 1 : $clog2(NC)
) (
    input  logic                clk,
    input  logic                en,
    input  logic [SW-1:0]       slot,
    input  logic [CW-1:0]       col,
    output logic                aclk,      // the array's gated clock: one CTS tree
    output logic [NS*NC-1:0]    wsel       // word w's decoded, latched select: data, stable while clk is high
);
    wire          clk_n, iclk_n;
    wire          en_l;
    wire [SW-1:0] slot_l;
    wire [CW-1:0] col_l;
    gf180mcu_fd_sc_mcu7t5v0__clkinv_1 u_ckn (.I(clk), .ZN(clk_n));
    aquafuse_lat #(.W(1)) u_en (.en(clk_n), .d(en), .q(en_l));
    // ENERGY as in aquafuse_wgate: the index latches open only in cycles that will write
    gf180mcu_fd_sc_mcu7t5v0__and2_1 u_ien (.A1(clk_n), .A2(en), .Z(iclk_n));
    aquafuse_lat #(.W(SW + CW)) u_idx (.en(iclk_n), .d({slot, col}), .q({slot_l, col_l}));
    // level 1: the array's only gate on the free-running clock
    gf180mcu_fd_sc_mcu7t5v0__and2_2 u_ag (.A1(clk), .A2(en_l), .Z(aclk));

    for (genvar s = 0; s < NS; s++) begin : g_s
        wire sel_s = (slot_l == SW'(s));
        for (genvar c = 0; c < NC; c++) begin : g_c
            assign wsel[s*NC + c] = sel_s & (col_l == CW'(c));
        end
    end
endmodule
`endif
