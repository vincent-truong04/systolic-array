// systolic_sram_top.sv -- systolic_top + on-chip weight (B) buffer in one OpenRAM SRAM macro (D-018)
//
// Interface changes vs systolic_top (everything else identical, D-005..D-017):
//   - b_row is gone. B lives in sky130_sram_1rw1r_80x64_8 (64 rows x 80 bits; row r = B-row,
//     B[k][j] at [j*DATA_W +: DATA_W], upper 80-N*DATA_W bits unused).
//   - Write port, usable at any time (port 0 of the macro):
//       wr_en, wr_addr, wr_data. A write accepted at edge W is visible to slices accepted at
//       edges > W. A slice accepted at the same edge W that reads wr_addr is undefined
//       (same-cycle read/write of one address, OpenRAM).
//   - b_base: sampled with the in_first slice. The k-th accepted slice of a job uses
//     row (b_base + k) mod 64. K <= 64 per job (<= 32 when ping-ponging halves). Not enforced.
//
// Timing (W = edge where this wrapper accepts a slice, D = 2):
//   W        input regs (D-015) capture a_col / first / last / b_base / valid          (stage s1)
//   W..W+1   addr1 = s1_first ? s1_base : ptr  (flops only), csb1 = !s1_valid
//   W+1      macro captures addr1, ptr <= addr1 + 1; a/flags move to stage s2
//   ~W+1.5   macro drives dout1 after the falling edge (OpenRAM): half a cycle left
//   W+2      core accepts {s2, dout1}; the core's own input register b_q is the first
//            flop after dout1 (no logic in the half-cycle path)
//   => every systolic_top timing is shifted by D = 2 edges: with E0 = edge where this wrapper
//      accepts in_last, out_valid after edges E0+2N+P+2 .. E0+3N-1+P+2.
//   in_ready: own register with the core's exact rule (low after the edge accepting in_last,
//      high again after edge E0+3N-1+P), i.e. the core's in_ready shifted D edges earlier, so
//      no extra gap between jobs and the core never gets a slice it can't accept
//      (checked white-box by tb/sram_top).

`timescale 1ns/1ps

module systolic_sram_top #(
    parameter int N      = 8,
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32,
    parameter bit PIPE_MAC = 1'b1,   // D-016
    parameter bit GATE_DATA = 1'b0,  // D-017
    localparam int ROW_W  = (N > 1) ? $clog2(N) : 1,
    localparam int ADDR_W = 6,       // 64 rows
    localparam int WORD_W = 80,      // macro word
    localparam int NMASK  = WORD_W / 8
) (
    input  logic                clk,
    input  logic                rst,

    // compute stream (A only)
    input  logic                in_valid,
    output logic                in_ready,
    input  logic                in_first,
    input  logic                in_last,
    input  logic [N*DATA_W-1:0] a_col,      // A[i][k] at [i*DATA_W +: DATA_W]
    input  logic [ADDR_W-1:0]   b_base,     // sampled with in_first

    // weight buffer write port
    input  logic                wr_en,
    input  logic [ADDR_W-1:0]   wr_addr,
    input  logic [N*DATA_W-1:0] wr_data,    // B[k][j] at [j*DATA_W +: DATA_W]

    output logic                out_valid,
    output logic [ROW_W-1:0]    out_row,
    output logic [N*ACC_W-1:0]  out_data
);
    localparam int ROWB = N * DATA_W;
    if (ROWB > WORD_W) begin : g_too_wide
        $error("systolic_sram_top: N*DATA_W = %0d exceeds the 80-bit SRAM word", ROWB);
    end
    if (DATA_W != 8) begin : g_bad_lane
        $error("systolic_sram_top: write mask assumes 8-bit lanes (DATA_W = 8)");
    end

    // ------------------------------------------------------------------
    // in_ready: copy of the core's rule (systolic_top controller), D edges earlier.
    // Low for the 3N-1+P edges after the edge that accepts in_last.
    // ------------------------------------------------------------------
    localparam int BUSY_LAST = 3*N - 2 + int'(PIPE_MAC);   // cnt value at the edge that re-opens
    localparam int BCNT_W    = $clog2(BUSY_LAST + 2);

    logic              in_fire;
    logic [BCNT_W-1:0] bcnt;

    assign in_fire = in_valid & in_ready;

    always_ff @(posedge clk) begin
        if (rst) begin
            in_ready <= 1'b1;
            bcnt     <= '0;
        end else if (in_ready) begin
            if (in_fire && in_last) begin
                in_ready <= 1'b0;
                bcnt     <= '0;
            end
        end else if (bcnt == BCNT_W'(BUSY_LAST)) begin
            in_ready <= 1'b1;
        end else begin
            bcnt <= bcnt + 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // Stage s1: input registers (D-015). Control reset; data not.
    // ------------------------------------------------------------------
    logic              s1_v, s1_f, s1_l;
    logic [ROWB-1:0]   s1_a;
    logic [ADDR_W-1:0] s1_base;

    always_ff @(posedge clk) begin
        if (rst) s1_v <= 1'b0;
        else     s1_v <= in_fire;
    end

    always_ff @(posedge clk) begin
        if (!GATE_DATA || in_fire) begin
            s1_f    <= in_first;
            s1_l    <= in_last;
            s1_a    <= a_col;
            s1_base <= b_base;
        end
    end

    // ------------------------------------------------------------------
    // Read address: b_base on the first slice, then auto-increment (mod 64).
    // ------------------------------------------------------------------
    logic [ADDR_W-1:0] ptr, rd_addr;

    assign rd_addr = s1_f ? s1_base : ptr;

    always_ff @(posedge clk) begin
        if (s1_v) ptr <= rd_addr + 1'b1;    // no reset needed: every job starts at b_base
    end

    // ------------------------------------------------------------------
    // Stage s2: a and flags wait while the macro reads B.
    // ------------------------------------------------------------------
    logic            s2_v, s2_f, s2_l;
    logic [ROWB-1:0] s2_a;

    always_ff @(posedge clk) begin
        if (rst) s2_v <= 1'b0;
        else     s2_v <= s1_v;
    end

    always_ff @(posedge clk) begin
        if (!GATE_DATA || s1_v) begin
            s2_f <= s1_f;
            s2_l <= s1_l;
            s2_a <= s1_a;
        end
    end

    // ------------------------------------------------------------------
    // Write port registers (D-015).
    // ------------------------------------------------------------------
    logic              wr_en_q;
    logic [ADDR_W-1:0] wr_addr_q;
    logic [ROWB-1:0]   wr_data_q;

    always_ff @(posedge clk) begin
        if (rst) wr_en_q <= 1'b0;
        else     wr_en_q <= wr_en;
    end

    always_ff @(posedge clk) begin
        if (!GATE_DATA || wr_en) begin
            wr_addr_q <= wr_addr;
            wr_data_q <= wr_data;
        end
    end

    // ------------------------------------------------------------------
    // Weight buffer macro (port 0: write only; port 1: read)
    // ------------------------------------------------------------------
    logic [WORD_W-1:0] din0, dout1;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [WORD_W-1:0] dout0;            // port 0 is never read
    /* verilator lint_on UNUSEDSIGNAL */

    assign din0 = {{(WORD_W-ROWB){1'b0}}, wr_data_q};

    sky130_sram_1rw1r_80x64_8 u_bbuf (
        .clk0  (clk),
        .csb0  (~wr_en_q),
        .web0  (1'b0),
        .wmask0(NMASK'((1 << N) - 1)),  // one 8-bit lane per column
        .addr0 (wr_addr_q),
        .din0  (din0),
        .dout0 (dout0),
        .clk1  (clk),
        .csb1  (~s1_v),                 // read only for accepted slices
        .addr1 (rd_addr),
        .dout1 (dout1)
    );

    // ------------------------------------------------------------------
    // Core (unchanged). Its input register b_q captures dout1 directly.
    // ------------------------------------------------------------------
    /* verilator lint_off UNUSEDSIGNAL */
    logic core_ready;                    // equal to in_ready D edges later (checked in tb)
    /* verilator lint_on UNUSEDSIGNAL */

    systolic_top #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W), .PIPE_MAC(PIPE_MAC), .GATE_DATA(GATE_DATA)) u_core (
        .clk      (clk),
        .rst      (rst),
        .in_valid (s2_v),
        .in_ready (core_ready),
        .in_first (s2_f),
        .in_last  (s2_l),
        .a_col    (s2_a),
        .b_row    (dout1[ROWB-1:0]),
        .out_valid(out_valid),
        .out_row  (out_row),
        .out_data (out_data)
    );

endmodule
