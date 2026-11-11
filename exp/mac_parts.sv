// mac_parts.sv -- area-breakdown experiment (EXP-001), NOT part of the design.
// Each module isolates one piece of rtl/pe.sv's datapath, with identical widths
// and expressions, so their synthesized areas can be compared with the full PE.
// All modules are purely combinational (no flops) except the reference pe itself.

`timescale 1ns/1ps
/* verilator lint_off DECLFILENAME */  // several small modules in one experiment file

// The PE's multiplier: signed 8 x 8 -> 16
module mult8 (
    input  logic signed [7:0]  a,
    input  logic signed [7:0]  b,
    output logic signed [15:0] prod
);
    assign prod = a * b;
endmodule

// The PE's accumulate adder: (first ? 0 : acc) + sign-extended 16-bit product -> 32
module acc_add32 (
    input  logic signed [31:0] acc,
    input  logic signed [15:0] prod,
    input  logic               first,
    output logic signed [31:0] acc_next
);
    logic signed [31:0] addend;
    assign addend   = first ? '0 : acc;
    assign acc_next = addend + {{16{prod[15]}}, prod};
endmodule
