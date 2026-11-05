`timescale 1ns/1ps
// Stem accumulator: a 4x4 stride-4 convolution computed as pixels arrive.
//
// WHY IT EXISTS. A 4x4 window spans four input rows, so the obvious streaming
// implementation buffers three input rows -- 96 x IN_CH bytes each, 864 B at
// IN_CH=3 -- which alone exceeds the whole line-buffer budget. Instead each
// pixel's contribution is accumulated into the output position it belongs to
// the moment it arrives, and only the OUTPUT row of partial sums is held:
// OUT_W x COUT accumulators, 300 B at 25x4x24-bit. Nothing upstream is stored.
//
// This works because stride == kernel: with padding = kernel/2 = 2 every input
// row and column maps to EXACTLY ONE output row and column, so no accumulator
// is ever needed for two windows at once. Mapping, for stride 4, pad 2:
//     or = (r + 2) >> 2      kr = r - 4*or + 2
//     oc = (c + 2) >> 2      kc = c - 4*oc + 2
// Rows 0..1 land in output row 0 (the first window is truncated by padding),
// rows 2..5 in output row 1, and so on. Verified against PresenceNet geometry:
// 54x96 in -> 14x25 out for gq54.
//
// IN_CH is a parameter and the module is correct for 1, 2 or 3 channels. That
// is deliberate: whether the chip can compute its own temporal channels is an
// open architecture question, and this block must not prejudge it.
//
// One input channel is consumed per cycle, COUT multipliers wide, so a pixel
// costs IN_CH cycles. At 54x96x3 that is 15,552 cycles per frame against
// 1.75M available at 26.3 MHz and 15 fps -- the stem is nowhere near the
// binding constraint.
//
// PRE-FREEZE, NON-MANUFACTURING. Not D3/D4/D5 exit evidence; decision 0009.
module aquafuse_stem_accum #(
    parameter int OUT_W  = 25,   // output columns
    parameter int COUT   = 4,    // stem output channels
    parameter int ACC_W  = 24
) (
    input  logic                        clk,
    input  logic                        rst_n,

    // one (position, channel) product set per cycle
    input  logic                        mac_en,
    input  logic [$clog2(OUT_W)-1:0]    mac_col,     // target output column
    input  logic signed [7:0]           mac_act,     // activation byte
    input  logic signed [8*COUT-1:0]    mac_wgt,     // COUT weights, lane 0 = MSB

    // TWO clears, and the distinction is the whole of RTL-8.
    //   bank_clear -- wipe every column. Frame start only.
    //   col_clear  -- wipe ONE column, the one being read this cycle.
    // A single bank-wide clear at the end of the row flush was the defect: the
    // sensor keeps streaming throughout the 13-cycle flush, so pixels of the
    // NEXT stem row are MACed in and then wiped. Clearing each column as it is
    // read cannot lose them, because a pixel's column is always read before
    // that pixel can arrive -- pixel c of the next row lands at core clock
    // ~4*(c+1) after the flush starts while its column is read at flush cycle
    // (c+PAD)/STRIDE, which is smaller for every c at any pixel rate down to
    // one pixel per clock.
    input  logic                        bank_clear,
    input  logic                        col_clear,
    input  logic [$clog2(OUT_W)-1:0]    clear_col,

    // requantised readout of one column
    input  logic [$clog2(OUT_W)-1:0]    rd_col,
    // One shift per output channel, lane 0 = MSB -- see aquafuse_conv_stage
    // for why per-channel and why it costs no multiplexer.
    input  logic [5*COUT-1:0]           rd_shift,
    input  logic                        rd_relu,
    // STREAM12C (DR 0093). The background the part subtracts, and the folded
    // batch-norm bias it adds, both in ACCUMULATOR units and both applied
    // before the requantisation -- d = acc - background + bias -- because the
    // model was trained on stem(frame - EMA(frame)) + bias, and by linearity
    // that is exactly stem(frame) - EMA(stem(frame)) + bias. Lane 0 = MSB.
    input  logic [32*COUT-1:0]          rd_sub,
    input  logic [32*COUT-1:0]          rd_bias,
    // the raw accumulator of the column being read, for the EMA update
    output logic [32*COUT-1:0]          rd_acc,
    output logic [8*COUT-1:0]           rd_byte      // lane 0 = MSB
);

`include "aquafuse_round.svh"

    // flat view for the one-hot read ports (aquafuse_sel), GF180 area
    wire [OUT_W*COUT*ACC_W-1:0] acc_flat;
    wire [COUT*ACC_W-1:0] rd_mac_raw, rd_out_raw, rd_mac_word, rd_out_word;
`ifdef AQUAFUSE_GF180_ICG
    // ser31: the same two read ports with their one-hot selects replicated per lane (aquafuse_sel_gf):
    // 13 select lines at fanout 80 per port become 4 x 13 at fanout 20
    aquafuse_sel_gf #(.N(OUT_W), .W(COUT*ACC_W), .L(COUT)) u_rd_mac (.words(acc_flat), .sel(mac_col), .y(rd_mac_raw));
    aquafuse_sel_gf #(.N(OUT_W), .W(COUT*ACC_W), .L(COUT)) u_rd_out (.words(acc_flat), .sel(rd_col),  .y(rd_out_raw));
`else
    aquafuse_sel #(.N(OUT_W), .W(COUT*ACC_W)) u_rd_mac (.words(acc_flat), .sel(mac_col), .y(rd_mac_raw));
    aquafuse_sel #(.N(OUT_W), .W(COUT*ACC_W)) u_rd_out (.words(acc_flat), .sel(rd_col),  .y(rd_out_raw));
`endif

    // LIVE FLAGS (GF180 area, ser14). A column whose live bit is 0 reads as zero whatever its
    // latches hold, so a clear is one flag flop instead of a write of COUT*ACC_W bits. That is
    // what lets the accumulators be latches written from ONE staging register (below): the
    // only write a latch ever takes is a MAC's sum, so every column's data input is the same
    // net and no column needs a zeroing gate per bit. Padded to the select's range so an index
    // past OUT_W reads 0, as aquafuse_sel's zero leaves do.
    localparam int CW = $clog2(OUT_W);
    localparam int NL = 1 << CW;
    logic [OUT_W-1:0] live;
    wire  [NL-1:0]    live_p = NL'(live);
    assign rd_mac_word = {(COUT*ACC_W){live_p[mac_col]}} & rd_mac_raw;
    assign rd_out_word = {(COUT*ACC_W){live_p[rd_col]}}  & rd_out_raw;

    // A SIGNED zero, and it has to be spelled out. `{ACC_W{1'b0}}` and a bare
    // `'0` are UNSIGNED, and a ternary with one unsigned operand makes the
    // whole expression unsigned -- which silently reinterprets a negative
    // accumulator as a large positive one. Written the unsigned way this module
    // saturated every channel of stem row 0 to 0x7f. Measured, twice.
    localparam logic signed [ACC_W-1:0] ACC_ZERO = '0;

    // ONE ADDER SET, shared, with the column select in the ENABLE rather than
    // in the data path. This is the third formulation of this block and the
    // first that is both correct and affordable; the other two are recorded
    // because each failed in a different way and neither failure was visible
    // from the source.
    //
    //   1. Two variable-indexed non-blocking writes to the same unpacked array
    //      in one always block -- `if (col_clear) acc[clear_col][l] <= 0;` then
    //      `if (mac_en) acc[mac_col][l] <= ...`. iverilog accepts it, warns
    //      about nothing, and simulates something else: written that way this
    //      module saturated every channel of stem row 0, a row in which no
    //      clear can fire.
    //   2. A loop over all OUT_W columns with the wipe and the product folded
    //      into each column's data path. Simulates correctly and costs +5,882
    //      CELLS -- measured, 37,180 -> 43,062 with no extra flops -- because
    //      an adder per accumulator is 52 adders where the design needs COUT.
    //      That is what pushed the die past GRT-0118.
    //
    // So: read the target column through a mux, add ONCE, and write back
    // through a decoded enable. Per column there is then only a comparator and
    // a clear, which is what the original `acc[mac_col][l] <= acc[mac_col][l] +
    // product` synthesised to before RTL-8 was fixed.
    //
    // A MAC and this column's clear can fall on the same cycle. The MAC WINS,
    // starting a fresh sum from zero: the readout is combinational off the
    // pre-clear value so the row being flushed is unaffected, and the arriving
    // pixel belongs to the NEXT row and is the only copy of itself. Priority
    // the other way -- clear beats MAC, which is what `else if` gives -- is
    // exactly how RTL-8 discarded pixels.
    wire clear_this = col_clear && (clear_col == mac_col);

    logic signed [ACC_W-1:0] acc_rd   [COUT-1:0];
    logic signed [ACC_W-1:0] acc_next [COUT-1:0];
    for (genvar l = 0; l < COUT; l++) begin : g_acc
        assign acc_rd[l] = $signed(rd_mac_word[l*ACC_W +: ACC_W]);
        assign acc_next[l] = (clear_this ? ACC_ZERO : acc_rd[l])
            + ACC_W'($signed(mac_act) * $signed(mac_wgt[8*(COUT-1-l) +: 8]));
    end

    // THE COLUMN STATE, same priority as the flop version it replaces (ser13 and before:
    // one gated flop row per column, each bit behind a zeroing gate): bank_clear, then MAC,
    // then column clear.
    //   live[p]  -- set by a MAC on p, cleared by bank_clear or by a clear of p.
    //   word p   -- latches, written only by a MAC on p (a MAC that loses to bank_clear may
    //               still write them; live is 0 then, so nothing ever reads that value).
    // Reset: live clears on rst_n, so a column reads zero from power-up whatever its latches
    // hold; the flop version relied on the first frame's bank_clear for the same thing.
    wire lclk;
    aquafuse_icg u_lcg (.clk(clk), .en(bank_clear | mac_en | col_clear), .gclk(lclk));
    always_ff @(posedge lclk or negedge rst_n) begin
        if (!rst_n)
            live <= '0;
        else
            for (int p = 0; p < OUT_W; p++) begin
                if (bank_clear)                              live[p] <= 1'b0;
                else if (mac_en && mac_col == CW'(p))        live[p] <= 1'b1;
                else if (col_clear && clear_col == CW'(p))   live[p] <= 1'b0;
            end
    end

    // LATCH STORAGE (GF180 area; the pattern of aquafuse_bg_store). A latch is ~30% smaller
    // than a flop, and with the clears gone every column's data input is the staging register
    // stage_q, so the per-bit zeroing gate goes too. stage_q takes the sum at the edge that
    // opens the target column's latches (both on mac_en, sampled the cycle before that edge),
    // so the latch ends its high phase holding exactly what the flop captured. A read of that
    // column in the next cycle sees the new sum, as it did from the flop.
    logic [COUT*ACC_W-1:0] acc_next_word, stage_q;
    for (genvar l = 0; l < COUT; l++) begin : g_nw
        assign acc_next_word[l*ACC_W +: ACC_W] = acc_next[l];
    end
    wire sclk;
    aquafuse_icg u_scg (.clk(clk), .en(mac_en), .gclk(sclk));
    always_ff @(posedge sclk) stage_q <= acc_next_word;
`ifdef AQUAFUSE_GF180_ICG
    // ser31: one explicit clock gate for the accumulator row (aclk), the column decode as data (wsel), and
    // one and2 per column and lane (aquafuse_lat_gf, COUT lanes of ACC_W latches). Same enable per latch.
    wire             wg_aclk;
    wire [OUT_W-1:0] wg_sel;
    aquafuse_wgate_gf #(.NS(1), .NC(OUT_W)) u_wg (.clk(clk), .en(mac_en), .slot(1'b0), .col(mac_col),
                                                  .aclk(wg_aclk), .wsel(wg_sel));
    for (genvar p = 0; p < OUT_W; p++) begin : g_col
        aquafuse_lat_gf #(.W(COUT*ACC_W), .L(COUT)) u_lat (.aclk(wg_aclk), .wsel(wg_sel[p]), .d(stage_q),
                                                           .q(acc_flat[p*COUT*ACC_W +: COUT*ACC_W]));
    end
`else
    wire [OUT_W-1:0] gclk_v;
    aquafuse_wgate #(.NS(1), .NC(OUT_W)) u_wg (.clk(clk), .en(mac_en), .slot(1'b0), .col(mac_col), .gclk(gclk_v));
    for (genvar p = 0; p < OUT_W; p++) begin : g_col
        aquafuse_lat #(.W(COUT*ACC_W)) u_lat (.en(gclk_v[p]), .d(stage_q),
                                              .q(acc_flat[p*COUT*ACC_W +: COUT*ACC_W]));
    end
`endif

    // Readout is split so the column select is a CONTINUOUS assign and the
    // requantisation is a per-lane assign. Doing the variable index inside an
    // always_comb makes iverilog fall back to "sensitive to all bits", which
    // it warns about and which is a needless simulation hazard in the one
    // block whose arithmetic must match the golden model exactly.
    logic signed [ACC_W-1:0] acc_sel [COUT-1:0];
    logic signed [31:0]      acc_x   [COUT-1:0];
    logic signed [23:0]      d_x     [COUT-1:0];   // 24 bits (GF180 area): |d_x| < 2**20
    for (genvar l = 0; l < COUT; l++) begin : g_sel
        assign acc_sel[l] = $signed(rd_out_word[l*ACC_W +: ACC_W]);
        assign acc_x[l]   = {{(32-ACC_W){acc_sel[l][ACC_W-1]}}, acc_sel[l]};
        assign rd_acc[32*(COUT-1-l) +: 32] = acc_x[l];
        // 32 bits throughout: |acc| < 2**20 and the background and bias are of
        // the same order, so the sum cannot reach the sign bit.
        assign d_x[l] = 24'(acc_x[l]) - 24'($signed(rd_sub[32*(COUT-1-l) +: 32]))
                                 + 24'($signed(rd_bias[32*(COUT-1-l) +: 32]));
        assign rd_byte[8*(COUT-1-l) +: 8] =
            round_sat_relu(d_x[l], rd_shift[5*(COUT-1-l) +: 5], rd_relu);
    end

endmodule
