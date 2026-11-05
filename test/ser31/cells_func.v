// ser31 equivalence checks only: the boolean function of the four GF180 cells the ser31 GF180 branch
// instantiates, for the yosys SAT proof (sel_equiv.ys). The simulation bench (tb_wgate_equiv.sv) runs on
// the PDK's own Verilog models instead (run_equiv.sh), which also checks the pin names.
module gf180mcu_fd_sc_mcu7t5v0__and2_1 (input A1, input A2, output Z);  assign Z = A1 & A2; endmodule
module gf180mcu_fd_sc_mcu7t5v0__and2_2 (input A1, input A2, output Z);  assign Z = A1 & A2; endmodule
module gf180mcu_fd_sc_mcu7t5v0__clkinv_1 (input I, output ZN);          assign ZN = ~I;     endmodule
module gf180mcu_fd_sc_mcu7t5v0__latq_1 (input E, input D, output reg Q); always_latch if (E) Q = D; endmodule
