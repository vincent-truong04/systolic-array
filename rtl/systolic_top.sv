// systolic_top.sv -- N x N output-stationary systolic matmul: C = A (N x K) * B (K x N)
//
// Agreed decisions (notes/design-decisions.md): D-005..D-015. In short:
//   input  : one k-slice per accepted cycle: a_col = A[:,k], b_row = B[k,:],
//            in_first on k=0, in_last on k=K-1 (both on one slice if K=1)
//   handshake: slice accepted on a rising edge where in_valid & in_ready
//            (in_ready is a register output; it is low from the edge that
//            accepts in_last until the drain finishes)
//   output : after a job, N rows of C, one per cycle, bottom row first:
//            out_valid=1, out_row = N-1 ... 0, out_data[j*ACC_W +: ACC_W] = C[out_row][j]
//            No backpressure: the consumer must take each row when presented.
//   All inputs and outputs registered (D-015).
//
// Timing (E0 = rising edge that accepts the in_last slice):
//   E0           input regs capture the last slice; in_ready <= 0
//   E0+1+i+j     PE(i,j) accumulates its last term (skew lane 0 is a wire)
//   E0+2N-1      PE(N-1,N-1) done -> drain <= 1
//   E0+2N+d      d = 0..N-1: out regs capture bottom row = C row N-1-d,
//                and every acc shifts down one row
//   E0+3N-1      last drain edge: drain <= 0, in_ready <= 1
//   => out_valid high after edges E0+2N .. E0+3N-1; next slice accepted at E0+3N earliest.
//
// Datapath:
//   inputs ─► input regs ─► skew (a, b, {first,valid}) ─► pe_array ─► acc_bottom ─► output regs

`timescale 1ns/1ps

module systolic_top #(
    parameter int N      = 4,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32,
    localparam int ROW_W = (N > 1) ? $clog2(N) : 1
) (
    input  logic                clk,
    input  logic                rst,

    input  logic                in_valid,
    output logic                in_ready,
    input  logic                in_first,
    input  logic                in_last,
    input  logic [N*DATA_W-1:0] a_col,      // A[i][k] at [i*DATA_W +: DATA_W]
    input  logic [N*DATA_W-1:0] b_row,      // B[k][j] at [j*DATA_W +: DATA_W]

    output logic                out_valid,
    output logic [ROW_W-1:0]    out_row,
    output logic [N*ACC_W-1:0]  out_data    // C[out_row][j] at [j*ACC_W +: ACC_W]
);
    // ------------------------------------------------------------------
    // Input registers (D-015). Control is reset; data is not.
    // ------------------------------------------------------------------
    logic                in_fire;
    logic [N*DATA_W-1:0] a_q, b_q;
    logic                v_q, f_q;

    assign in_fire = in_valid & in_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            v_q <= 1'b0;
            f_q <= 1'b0;
        end else begin
            v_q <= in_fire;
            f_q <= in_fire & in_first;
        end
    end

    always_ff @(posedge clk) begin
        a_q <= a_col;
        b_q <= b_row;
    end

    // ------------------------------------------------------------------
    // Skew (D-011): row i of a and column j of b delayed by i / j cycles.
    // Flags are replicated per row and skewed with a reset-able instance.
    // ------------------------------------------------------------------
    logic [N*DATA_W-1:0] a_skew, b_skew;
    logic [2*N-1:0]      flags_in, flags_skew;
    logic [N-1:0]        valid_left, first_left;

    for (genvar i = 0; i < N; i++) begin : g_flags
        assign flags_in[2*i +: 2] = {f_q, v_q};
        assign valid_left[i]      = flags_skew[2*i];
        assign first_left[i]      = flags_skew[2*i+1];
    end

    skew #(.LANES(N), .W(DATA_W), .HAS_RESET(1'b0)) u_skew_a (
        .clk(clk), .rst(rst), .din(a_q), .dout(a_skew));
    skew #(.LANES(N), .W(DATA_W), .HAS_RESET(1'b0)) u_skew_b (
        .clk(clk), .rst(rst), .din(b_q), .dout(b_skew));
    skew #(.LANES(N), .W(2), .HAS_RESET(1'b1)) u_skew_flags (
        .clk(clk), .rst(rst), .din(flags_in), .dout(flags_skew));

    // ------------------------------------------------------------------
    // PE array
    // ------------------------------------------------------------------
    logic                drain_q;
    logic [N*ACC_W-1:0]  acc_bottom;

    pe_array #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)) u_array (
        .clk       (clk),
        .rst       (rst),
        .drain     (drain_q),
        .a_left    (a_skew),
        .valid_left(valid_left),
        .first_left(first_left),
        .b_top     (b_skew),
        .acc_bottom(acc_bottom)
    );

    // ------------------------------------------------------------------
    // Controller (D-012, D-013)
    //   S_COMPUTE : in_ready=1, accept slices; on accepting in_last -> S_WAIT
    //   S_WAIT    : let the last term reach PE(N-1,N-1): 2N-1 edges after E0
    //   S_DRAIN   : drain=1 for N edges, outputs captured
    // in_ready and drain are registers (computed from the next state).
    // ------------------------------------------------------------------
    typedef enum logic [1:0] {S_COMPUTE, S_WAIT, S_DRAIN} state_t;
    localparam int CNT_W = $clog2(2*N);    // holds 0 .. 2N-2

    state_t           state;
    logic [CNT_W-1:0] cnt;

    always_ff @(posedge clk) begin
        if (rst) begin
            state    <= S_COMPUTE;
            cnt      <= '0;
            in_ready <= 1'b1;
            drain_q  <= 1'b0;
        end else begin
            unique case (state)
                S_COMPUTE: if (in_fire && in_last) begin   // edge E0
                    state    <= S_WAIT;
                    cnt      <= '0;
                    in_ready <= 1'b0;
                end
                S_WAIT: begin                               // edges E0+1 .. E0+2N-1
                    if (cnt == CNT_W'(2*N-2)) begin         // edge E0+2N-1
                        state   <= S_DRAIN;
                        cnt     <= '0;
                        drain_q <= 1'b1;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end
                S_DRAIN: begin                              // edges E0+2N .. E0+3N-1
                    if (cnt == CNT_W'(N-1)) begin           // edge E0+3N-1
                        state    <= S_COMPUTE;
                        cnt      <= '0;
                        drain_q  <= 1'b0;
                        in_ready <= 1'b1;
                    end else begin
                        cnt <= cnt + 1'b1;
                    end
                end
                default: state <= S_COMPUTE;
            endcase
        end
    end

    // ------------------------------------------------------------------
    // Output registers (D-014, D-015). out_valid reset; row/data not.
    // On drain edge d (cnt = d) the bottom row holds C row N-1-d.
    // ------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) out_valid <= 1'b0;
        else     out_valid <= drain_q;
    end

    always_ff @(posedge clk) begin
        out_row  <= ROW_W'(N-1) - ROW_W'(cnt);
        out_data <= acc_bottom;
    end

endmodule
