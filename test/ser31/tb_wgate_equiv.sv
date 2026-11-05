`timescale 1ns/1ps
// ser31 equivalence bench (VPS only; run_equiv.sh). For each of the five storage arrays ser31 changes,
// the t5 GF180 write structure (aquafuse_wgate + one aquafuse_lat per word) and the ser31 one
// (aquafuse_wgate_gf + one aquafuse_lat_gf per word, L lane gates) are driven with the SAME random
// en / slot / col / d, and every stored bit is compared at six points in every clock cycle: just after
// each edge, mid-phase and just before the next edge. slot and col are drawn over their whole binary
// range, so out-of-range addresses (no word written) are covered. d changes 1 ns after the rising edge,
// as a flop's clock-to-Q does (upd_q / stage_q / in_q / wr_q are flops on the same edge in the part).
// Built with the PDK's own cell models (run_equiv.sh), so cell pin names and functions are the real ones.
//
// A missing, extra or mistimed lane enable shows up as a stored-bit mismatch: d is fresh random data
// every cycle, so a wrong enable changes the stored word with probability 1 - 2**-LW per lane.
module wg_pair #(
    parameter int NS = 1, parameter int NC = 4, parameter int L = 1, parameter int LW = 8,
    parameter int SW = (NS <= 1) ? 1 : $clog2(NS),
    parameter int CW = (NC <= 1) ? 1 : $clog2(NC)
) (
    input  logic clk,
    input  logic en,
    input  logic [SW-1:0] slot,
    input  logic [CW-1:0] col,
    input  logic [L*LW-1:0] d,
    output logic [NS*NC*L*LW-1:0] q_gold,
    output logic [NS*NC*L*LW-1:0] q_gate
);
    localparam int W = L * LW;
    // t5: one gated clock per word
    wire [NS*NC-1:0] gclk_v;
    aquafuse_wgate #(.NS(NS), .NC(NC)) u_old (.clk(clk), .en(en), .slot(slot), .col(col), .gclk(gclk_v));
    for (genvar w = 0; w < NS*NC; w++) begin : g_old
        aquafuse_lat #(.W(W)) u_lat (.en(gclk_v[w]), .d(d), .q(q_gold[w*W +: W]));
    end
    // ser31: one array gate + data select, L lane gates per word
    wire aclk;
    wire [NS*NC-1:0] wsel;
    aquafuse_wgate_gf #(.NS(NS), .NC(NC)) u_new (.clk(clk), .en(en), .slot(slot), .col(col), .aclk(aclk), .wsel(wsel));
    for (genvar w = 0; w < NS*NC; w++) begin : g_new
        aquafuse_lat_gf #(.W(W), .L(L)) u_lat (.aclk(aclk), .wsel(wsel[w]), .d(d), .q(q_gate[w*W +: W]));
    end
endmodule

module tb_wgate_equiv;
    localparam real T = 160.0;          // the SDC's period
    localparam int  CYCLES = 20000;
    logic clk = 1'b0;
    always #(T/2) clk = ~clk;

    // the five arrays: bg store, stem accumulator, b1 row store, b2 row store, temporal head
    logic en0, en1, en2, en3, en4;
    logic [0:0] s0, s1;  logic [1:0] s2, s3, s4;
    logic [6:0] c0;      logic [3:0] c1, c2;      logic [2:0] c3;  logic [4:0] c4;
    logic [35:0] d0;     logic [79:0] d1;         logic [27:0] d2; logic [41:0] d3; logic [9:0] d4;
    wire [91*36-1:0] g0, n0;   wire [13*80-1:0] g1, n1;   wire [39*28-1:0] g2, n2;
    wire [28*42-1:0] g3, n3;   wire [84*10-1:0] g4, n4;
    wg_pair #(.NS(1), .NC(91), .L(4), .LW(9))  p_bg   (.clk(clk), .en(en0), .slot(s0), .col(c0), .d(d0), .q_gold(g0), .q_gate(n0));
    wg_pair #(.NS(1), .NC(13), .L(4), .LW(20)) p_stem (.clk(clk), .en(en1), .slot(s1), .col(c1), .d(d1), .q_gold(g1), .q_gate(n1));
    wg_pair #(.NS(3), .NC(13), .L(4), .LW(7))  p_b1   (.clk(clk), .en(en2), .slot(s2), .col(c2), .d(d2), .q_gold(g2), .q_gate(n2));
    wg_pair #(.NS(4), .NC(7),  .L(6), .LW(7))  p_b2   (.clk(clk), .en(en3), .slot(s3), .col(c3), .d(d3), .q_gold(g3), .q_gate(n3));
    wg_pair #(.NS(3), .NC(28), .L(1), .LW(10)) p_th   (.clk(clk), .en(en4), .slot(s4), .col(c4), .d(d4), .q_gold(g4), .q_gate(n4));

    int errors = 0, checks = 0, writes = 0;
    task automatic check(input string where);
        checks++;
        if (g0 !== n0) begin errors++; if (errors < 10) $display("MISMATCH bg   %s t=%0t", where, $time); end
        if (g1 !== n1) begin errors++; if (errors < 10) $display("MISMATCH stem %s t=%0t", where, $time); end
        if (g2 !== n2) begin errors++; if (errors < 10) $display("MISMATCH b1   %s t=%0t", where, $time); end
        if (g3 !== n3) begin errors++; if (errors < 10) $display("MISMATCH b2   %s t=%0t", where, $time); end
        if (g4 !== n4) begin errors++; if (errors < 10) $display("MISMATCH th   %s t=%0t", where, $time); end
    endtask

    function automatic logic [79:0] r80();
        return {$urandom, $urandom, $urandom};
    endfunction

    initial begin
        {en0, en1, en2, en3, en4} = '0;
        {s0, s1, s2, s3, s4} = '0; {c0, c1, c2, c3, c4} = '0;
        d0 = '0; d1 = '0; d2 = '0; d3 = '0; d4 = '0;
        // first write cycles: every word of every array, in order, so no word is left X before the
        // random phase (X == X compares equal, but a defined store makes every later check meaningful)
        for (int w = 0; w < 91; w++) begin
            @(posedge clk); #1;
            en0 = 1; c0 = 7'(w);           d0 = 36'(r80());
            en1 = 1; c1 = 4'(w % 13);      d1 = r80();
            en2 = 1; s2 = 2'((w / 13) % 3); c2 = 4'(w % 13); d2 = 28'(r80());
            en3 = 1; s3 = 2'((w / 7) % 4);  c3 = 3'(w % 7);  d3 = 42'(r80());
            en4 = 1; s4 = 2'((w / 28) % 3); c4 = 5'(w % 28); d4 = 10'(r80());
        end
        for (int i = 0; i < CYCLES; i++) begin
            // sample points stay clear of the 1 ns clock-to-Q of the delayed models (rise+1, rise+2,
            // fall+1), so gold and gate are never compared inside one simulation time step
            @(posedge clk); #0.5;
            check("rise+0.5");
            #0.5;
            // the part's inputs: launched by flops on this edge
            en0 = $urandom % 2; s0 = $urandom; c0 = $urandom; d0 = 36'(r80());
            en1 = $urandom % 2; s1 = $urandom; c1 = $urandom; d1 = r80();
            en2 = $urandom % 2; s2 = $urandom; c2 = $urandom; d2 = 28'(r80());
            en3 = $urandom % 2; s3 = $urandom; c3 = $urandom; d3 = 42'(r80());
            en4 = $urandom % 2; s4 = $urandom; c4 = $urandom; d4 = 10'(r80());
            writes += en0 + en1 + en2 + en3 + en4;
            #(T/4 - 1);     check("high-mid");        // rise + 40
            #(T/4 - 2);     check("before-fall");     // rise + 78
            @(negedge clk); #2.5; check("fall+2.5");
            #(T/4 - 2.5);   check("low-mid");         // fall + 40
            #(T/4 - 3);     check("before-rise");     // fall + 77
        end
        $display("WGATE_EQUIV %s: %0d cycles, %0d checks, %0d write requests, %0d mismatches",
                 (errors == 0) ? "PASS" : "FAIL", CYCLES, checks, writes, errors);
        $finish;
    end
endmodule
