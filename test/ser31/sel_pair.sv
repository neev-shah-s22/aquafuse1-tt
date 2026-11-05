// ser31 equivalence checks only: the two read-port configurations ser31 changes, behavioural
// (aquafuse_sel) against GF180 (aquafuse_sel_gf), for the SAT proof in sel_equiv.ys.
module sel_gold_bg (input logic [91*36-1:0] words, input logic [6:0] sel, output logic [35:0] y);
    aquafuse_sel    #(.N(91), .W(36))        u (.words(words), .sel(sel), .y(y));
endmodule
module sel_gate_bg (input logic [91*36-1:0] words, input logic [6:0] sel, output logic [35:0] y);
    aquafuse_sel_gf #(.N(91), .W(36), .L(4)) u (.words(words), .sel(sel), .y(y));
endmodule
module sel_gold_stem (input logic [13*80-1:0] words, input logic [3:0] sel, output logic [79:0] y);
    aquafuse_sel    #(.N(13), .W(80))        u (.words(words), .sel(sel), .y(y));
endmodule
module sel_gate_stem (input logic [13*80-1:0] words, input logic [3:0] sel, output logic [79:0] y);
    aquafuse_sel_gf #(.N(13), .W(80), .L(4)) u (.words(words), .sel(sel), .y(y));
endmodule
