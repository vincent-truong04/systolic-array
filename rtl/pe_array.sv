// pe_array.sv -- N x N grid of output-stationary PEs
//
// Wiring (indices: row i = 0..N-1 top to bottom, column j = 0..N-1 left to right):
//
//             b_top[0]   b_top[1]  ...          acc_in of row 0 = 0
//                │          │
//  a_left[0] ─► PE(0,0) ─► PE(0,1) ─► ...  ─► (a_out of last column unused)
//                │          │
//  a_left[1] ─► PE(1,0) ─► PE(1,1) ─► ...
//                │          │
//               ...        ...
//                ▼          ▼
//          acc_bottom[0] acc_bottom[1]        (b_out of the bottom row unused)
//
//  horizontal (a_h, v_h, f_h): activation + valid + first, moving right
//  vertical   (b_v)          : weight, moving down
//  vertical   (c_v)          : acc_out -> acc_in of the PE below, used only
//                              while drain=1 to shift results out the bottom
//
// Inputs must already be skewed (row i delayed i cycles, column j delayed j
// cycles; see skew.sv) so a[i][k] and b[k][j] meet at PE(i,j).
// drain is broadcast to all N*N PEs (D-013) and must come from a register.

`timescale 1ns/1ps

module pe_array #(
    parameter int N      = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32,
    parameter bit PIPE_MAC = 1'b1,  // D-016, passed to every PE
    parameter bit GATE_DATA = 1'b0  // D-017, passed to every PE
) (
    input  logic                clk,
    input  logic                rst,
    input  logic                drain,

    input  logic [N*DATA_W-1:0] a_left,      // row i at [i*DATA_W +: DATA_W]
    input  logic [N-1:0]        valid_left,  // per row, travels with a
    input  logic [N-1:0]        first_left,  // per row, travels with a
    input  logic [N*DATA_W-1:0] b_top,       // column j at [j*DATA_W +: DATA_W]

    output logic [N*ACC_W-1:0]  acc_bottom   // acc_out of PE(N-1, j) at [j*ACC_W +: ACC_W]
);
    // Index N on the "outgoing" side is the edge of the array. Those signals
    // (a/valid/first leaving the right edge, b leaving the bottom) drive nothing,
    // so synthesis will delete the flops that produce them.
    /* verilator lint_off UNUSEDSIGNAL */
    logic signed [DATA_W-1:0] a_h [N][N+1];
    logic                     v_h [N][N+1];
    logic                     f_h [N][N+1];
    logic signed [DATA_W-1:0] b_v [N+1][N];
    /* verilator lint_on UNUSEDSIGNAL */
    logic signed [ACC_W-1:0]  c_v [N+1][N];

    for (genvar i = 0; i < N; i++) begin : g_left_edge
        assign a_h[i][0] = a_left[i*DATA_W +: DATA_W];
        assign v_h[i][0] = valid_left[i];
        assign f_h[i][0] = first_left[i];
    end

    for (genvar j = 0; j < N; j++) begin : g_top_bottom_edge
        assign b_v[0][j] = b_top[j*DATA_W +: DATA_W];
        assign c_v[0][j] = '0;                              // row 0 drains in zeros
        assign acc_bottom[j*ACC_W +: ACC_W] = c_v[N][j];
    end

    for (genvar i = 0; i < N; i++) begin : g_row
        for (genvar j = 0; j < N; j++) begin : g_col
            pe #(.DATA_W(DATA_W), .ACC_W(ACC_W), .PIPE_MAC(PIPE_MAC), .GATE_DATA(GATE_DATA)) u_pe (
                .clk       (clk),
                .rst       (rst),
                .a_in      (a_h[i][j]),
                .b_in      (b_v[i][j]),
                .valid_in  (v_h[i][j]),
                .first_in  (f_h[i][j]),
                .drain     (drain),
                .acc_in    (c_v[i][j]),
                .a_out     (a_h[i][j+1]),
                .b_out     (b_v[i+1][j]),
                .valid_out (v_h[i][j+1]),
                .first_out (f_h[i][j+1]),
                .acc_out   (c_v[i+1][j])
            );
        end
    end

endmodule
