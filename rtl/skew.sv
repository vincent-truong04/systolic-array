// skew.sv -- triangular delay line for systolic input skewing (D-011)
//
// LANES parallel lanes of W bits. Lane i is delayed by i clock cycles:
//   lane 0: no delay (wire)       lane 1: 1 register      ...   lane L-1: L-1 registers
// Total registers: W * LANES*(LANES-1)/2   (e.g. 8 bits x 28 = 224 FFs for LANES=8)
//
//   din lane0 ──────────────────────────► dout lane0
//   din lane1 ──[R]─────────────────────► dout lane1
//   din lane2 ──[R]──[R]────────────────► dout lane2
//   din lane3 ──[R]──[R]──[R]───────────► dout lane3
//
// Why: lane i feeds row i (for a) or column i (for b) of the array. Delaying it
// by i cycles makes a[i][k] and b[k][j] meet at PE(i,j) on the same cycle.
//
// HAS_RESET=1 clears the registers on rst (use for valid/first flags, so no
// stale "valid" survives reset). HAS_RESET=0 for data: smaller flops, fewer
// reset loads, and stale data is harmless while valid=0.
// Lane 0 is a wire, so it is never reset (its source is already registered).

`timescale 1ns/1ps

module skew #(
    parameter int LANES     = 4,
    parameter int W         = 8,
    parameter bit HAS_RESET = 1'b0
) (
    /* verilator lint_off UNUSEDSIGNAL */  // unused only when LANES == 1 (no registers)
    input  logic               clk,
    input  logic               rst,
    /* verilator lint_on UNUSEDSIGNAL */
    input  logic [LANES*W-1:0] din,
    output logic [LANES*W-1:0] dout
);
    // lane 0: zero delay
    assign dout[0 +: W] = din[0 +: W];

    for (genvar i = 1; i < LANES; i++) begin : g_lane
        logic [W-1:0] sr [i];  // i-stage shift register; sr[i-1] is the output

        always_ff @(posedge clk) begin
            if (HAS_RESET && rst) begin
                for (int k = 0; k < i; k++) sr[k] <= '0;
            end else begin
                sr[0] <= din[i*W +: W];
                for (int k = 1; k < i; k++) sr[k] <= sr[k-1];
            end
        end

        assign dout[i*W +: W] = sr[i-1];
    end

endmodule
