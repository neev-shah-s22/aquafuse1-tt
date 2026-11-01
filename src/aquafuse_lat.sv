`timescale 1ns/1ps
// W transparent-high latches sharing one enable. q follows d while en is high
// and holds when it falls. The GF180 flow has no latch map for Yosys (it stops
// with "Unmapped Yosys instances"), so the cell is instantiated, as the clock
// gate is (aquafuse_icg). The behavioural branch is the same function.
//
// ENABLE BUFFERS (ser16). A storage word's enable comes from aquafuse_wgate's AND of the clock, so the flow treats
// it as a clock net: the resizer's repair_design leaves clock nets alone and CTS does not build trees through plain
// logic. Unbuffered, one AND drove all W enables: the routed ser15-v25 had ~380 such drivers over their cap limit and
// 125 ns slews on the stem's 80-bit words (limit 3 ns; DR013 update 7). So a word of EB_MIN or more bits gets one
// clkbuf_2 per group of at most EB_GROUP latches. Delay only, no change of function. The write gate's own enable and
// index latches (W <= 8) stay unbuffered, so its clock-gating timing is as before.
module aquafuse_lat #(
    parameter int W = 1
) (
    input  logic         en,
    input  logic [W-1:0] d,
    output logic [W-1:0] q
);
`ifdef AQUAFUSE_GF180_ICG
    localparam int EB_MIN   = 16;
    localparam int EB_GROUP = 20;
    localparam int NG = (W >= EB_MIN) ? (W + EB_GROUP - 1) / EB_GROUP : 1;
    localparam int GW = (W + NG - 1) / NG;        // latches per buffer, balanced
    wire [NG-1:0] en_b;
    if (W >= EB_MIN) begin : g_eb
        for (genvar g = 0; g < NG; g++) begin : g_buf
            gf180mcu_fd_sc_mcu7t5v0__clkbuf_2 u_eb (.I(en), .Z(en_b[g]));
        end
    end else begin : g_nb
        assign en_b = en;
    end
    for (genvar i = 0; i < W; i++) begin : g_bit
        gf180mcu_fd_sc_mcu7t5v0__latq_1 u_l (.E(en_b[i / GW]), .D(d[i]), .Q(q[i]));
    end
`else
    always_latch if (en) q = d;
`endif
endmodule
