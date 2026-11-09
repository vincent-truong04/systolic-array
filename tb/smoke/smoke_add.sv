// Milestone 0 toolchain smoke test only -- NOT part of the accelerator.
// Registered signed 8-bit add with synchronous active-high reset.
`timescale 1ns/1ps
module smoke_add (
    input  logic              clk,
    input  logic              rst,
    input  logic signed [7:0] a,
    input  logic signed [7:0] b,
    output logic signed [8:0] q
);
    always_ff @(posedge clk) begin
        if (rst) q <= '0;
        else     q <= a + b;   // both operands signed -> sign-extended to 9 bits
    end
endmodule
