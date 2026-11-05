`timescale 1ns/1ps
// W transparent-high latches sharing one enable. q follows d while en is high
// and holds when it falls. The GF180 flow has no latch map for Yosys (it stops
// with "Unmapped Yosys instances"), so the cell is instantiated, as the clock
// gate is (aquafuse_icg). The behavioural branch is the same function.
module aquafuse_lat #(
    parameter int W = 1
) (
    input  logic         en,
    input  logic [W-1:0] d,
    output logic [W-1:0] q
);
`ifdef AQUAFUSE_GF180_ICG
    for (genvar i = 0; i < W; i++) begin : g_bit
        gf180mcu_fd_sc_mcu7t5v0__latq_1 u_l (.E(en), .D(d[i]), .Q(q[i]));
    end
`else
    always_latch if (en) q = d;
`endif
endmodule

`ifdef AQUAFUSE_GF180_ICG
// ser31 (DR013, idea 2): one stored word on GF180, with its own write gates. GF180 only; the behavioural
// build has no such module and keeps aquafuse_lat with one enable per word.
//
// L LANE GATES PER WORD. Lane l is bits [l*LW +: LW], LW = W / L, and its latches take their enable from
// u_lg = and2(aclk, wsel): the array's gated clock (aquafuse_wgate_gf) and this word's latched select.
// Every lane gate computes the same function, aquafuse_wgate's gclk for this word, so each latch sees the
// enable it had before; only the driver is split. One gate per lane keeps each enable net inside the
// lane's bit-slice (t5's bg word roots were ~1.6 mm of wire because placement spreads a 36-bit word
// over 3-4 bit-slice clusters; its 10-latch temporal words were 0.032 pF). src/pnr.sdc makes CTS skip
// the u_lg output nets, so a lane gate drives its 7-20 latch E pins directly, with no clock buffer.
// and2_2: 20 latq_1 E pins plus a lane's wire is ~0.03-0.08 pF.
//
// The instance names keep the old storage paths (u_lat.g_bit[i].u_l), which scripts key on.
module aquafuse_lat_gf #(
    parameter int W = 1,
    parameter int L = 1             // lanes
) (
    input  logic         aclk,      // the array's gated clock (aquafuse_wgate_gf)
    input  logic         wsel,      // this word's latched select, stable while aclk is high
    input  logic [W-1:0] d,
    output logic [W-1:0] q
);
    localparam int LW = (W + L - 1) / L;    // == W / L for every caller; rounded up so i / LW < L always
    wire [L-1:0] lgclk;
    for (genvar l = 0; l < L; l++) begin : g_l
        gf180mcu_fd_sc_mcu7t5v0__and2_2 u_lg (.A1(aclk), .A2(wsel), .Z(lgclk[l]));
    end
    for (genvar i = 0; i < W; i++) begin : g_bit
        gf180mcu_fd_sc_mcu7t5v0__latq_1 u_l (.E(lgclk[i / LW]), .D(d[i]), .Q(q[i]));
    end
endmodule
`endif
