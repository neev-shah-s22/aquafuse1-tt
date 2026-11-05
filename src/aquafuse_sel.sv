`timescale 1ns/1ps
// Read port of a flat word store: y = words[sel], as a BALANCED binary tree.
//
// WHY A MODULE. The clock-gated stores are flat vectors (aquafuse_bg_store),
// and their first read port was a loop -- `if (sel == i) y = words[i]` -- which
// yosys builds as a PRIORITY chain: 91 multiplexers deep for the background
// store. At the slow corner that one structure put the part 9.8 ns over its
// 38 ns clock (stream12c_8x4_r5, max_ss_100C_1v60: 5,235 failing endpoints, all
// downstream of a store read). A tree has the same multiplexer count and
// $clog2(N) levels.
//
// The tree is a heap in one flat vector: node n (1 .. NP-1) selects between
// children 2n and 2n+1 on address bit AW-1-floor(log2 n); leaf NP+i is word i,
// zero past N. Flat because this yosys rejects multi-dimensional packed nets.
module aquafuse_sel #(
    parameter int N = 4,      // words
    parameter int W = 8       // bits per word
) (
    input  logic [N*W-1:0]          words,   // word i at words[i*W +: W]
    input  logic [$clog2(N)-1:0]    sel,
    output logic [W-1:0]            y
);
    localparam int AW = (N <= 1) ? 1 : $clog2(N);
    localparam int NP = 1 << AW;

    // ONE-HOT AND-OR (GF180 area). The select is decoded once and shared by all W
    // bits; each bit is then an AND-OR over the words, which maps to AOI22 pairs
    // (about half the area per input of a 2:1 multiplexer tree).
    logic [N-1:0] hot;
    for (genvar i = 0; i < N; i++) begin : g_hot
        assign hot[i] = (sel == AW'(i));
    end
    for (genvar b = 0; b < W; b++) begin : g_bit
        logic [N-1:0] terms;
        for (genvar i = 0; i < N; i++) begin : g_t
            assign terms[i] = words[i*W + b] & hot[i];
        end
        assign y[b] = |terms;
    end
endmodule

`ifdef AQUAFUSE_GF180_ICG
// ser31 (DR013, idea 5): aquafuse_sel with the one-hot select REPLICATED PER LANE. GF180 only; the
// behavioural build keeps aquafuse_sel above, which is the same function.
//
// WHY. aquafuse_sel's hot[i] is one net per word that reaches every bit of the word: 36 AOI inputs for a
// bg entry, 80 for a stem column. In t5 about 25 of the 51 nets over the data rule at max_ss are these bg
// hot lines (one nor2_2 driving AOIs spread over the word's 3-4 bit-slice clusters, plus big max_cap
// buffers), and ~800 of t5's 1,855 repair buffers sit on nor2/nor4 decode outputs. Here hot is built
// per LANE, hot_l[l][i] = u_hs (an instantiated and2) of a high and a low predecode line, so each copy
// only feeds its own lane's LW AOI inputs and stays inside that lane's bit-slice. Instantiated, so
// opt_merge/ABC cannot fold the L copies back into one (the ser18-b u_eb buffers, identical-input
// instantiated cells, all survived synthesis: 396 of 396). The predecode lines are the remaining
// high-fanout nets: NH + NLO of them (12 + 8 for the bg store, 4 + 4 per stem port), plain logic the resizer
// may buffer as data.
//
// SAME FUNCTION, FOR EVERY sel. AL = AW/2 low address bits; for i < N,
//   (sel >> AL == i >> AL) & (sel % 2**AL == i % 2**AL)  <=>  sel == i,
// which is aquafuse_sel's hot[i] for any two-valued sel, including sel >= N (no word: y = 0 in both).
// The AND-OR per bit is aquafuse_sel's with hot[i] replaced by its lane's copy.
module aquafuse_sel_gf #(
    parameter int N = 4,      // words
    parameter int W = 8,      // bits per word
    parameter int L = 1       // lanes: bit b belongs to lane b / LW
) (
    input  logic [N*W-1:0]          words,   // word i at words[i*W +: W]
    input  logic [$clog2(N)-1:0]    sel,
    output logic [W-1:0]            y
);
    localparam int AW  = (N <= 1) ? 1 : $clog2(N);
    localparam int AL  = AW / 2;                           // low address bits in the low predecode
    localparam int NLO = (N < (1 << AL)) ? N : (1 << AL);  // low predecode lines
    localparam int NH  = ((N - 1) >> AL) + 1;              // high predecode lines
    localparam int LW  = (W + L - 1) / L;                  // bits per lane (W / L for every caller)
    localparam logic [AW-1:0] LOMASK = AW'((1 << AL) - 1);

    wire [AW-1:0] sel_w = AW'(sel);
    logic [NH-1:0]  hi_hot;
    logic [NLO-1:0] lo_hot;
    for (genvar j = 0; j < NH; j++) begin : g_hi
        assign hi_hot[j] = ((sel_w >> AL) == AW'(j));
    end
    for (genvar k = 0; k < NLO; k++) begin : g_lo
        assign lo_hot[k] = ((sel_w & LOMASK) == AW'(k));
    end

    wire [L*N-1:0] hot_l;       // lane l, word i at l*N + i
    for (genvar l = 0; l < L; l++) begin : g_l
        for (genvar i = 0; i < N; i++) begin : g_w
            if (LW > 12) begin : g_x2
                gf180mcu_fd_sc_mcu7t5v0__and2_2 u_hs (.A1(hi_hot[i >> AL]), .A2(lo_hot[i & ((1 << AL) - 1)]),
                                                     .Z(hot_l[l*N + i]));
            end else begin : g_x1
                gf180mcu_fd_sc_mcu7t5v0__and2_1 u_hs (.A1(hi_hot[i >> AL]), .A2(lo_hot[i & ((1 << AL) - 1)]),
                                                     .Z(hot_l[l*N + i]));
            end
        end
    end
    for (genvar b = 0; b < W; b++) begin : g_bit
        logic [N-1:0] terms;
        for (genvar i = 0; i < N; i++) begin : g_t
            assign terms[i] = words[i*W + b] & hot_l[(b / LW)*N + i];
        end
        assign y[b] = |terms;
    end
endmodule
`endif
