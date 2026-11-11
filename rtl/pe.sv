// pe.sv -- output-stationary processing element (PE)
//
// PE(i,j) of the systolic array. It accumulates one output element C[i][j]
// locally while forwarding its operands to its neighbours:
//   activation a: enters from the left, leaves to the right (1-cycle delay)
//   weight     b: enters from the top,  leaves to the bottom (1-cycle delay)
//   valid/first : travel with a (the input skew lines a[i][k] up with b[k][j])
//
// Agreed decisions (notes/design-decisions.md):
//   D-005  first_in & valid_in starts a new job: acc <= a*b  (no global clear)
//   D-006  INT32 accumulate wraps on overflow (two's complement, no saturation)
//   D-007  synchronous, active-high rst
//   D-008  valid_in gates accumulation; when low, acc holds
//   D-009  single-cycle MAC (PIPE_MAC=0), superseded by
//   D-016  optional product register (PIPE_MAC=1, default): stage 1 registers
//          a*b, stage 2 adds it; the valid/first that go with the product are
//          the already-registered valid_out/first_out (no extra flag flops)
//   D-013  stop-and-drain: when drain=1, acc <= acc_in (results shift down
//          the column, one row per cycle; the controller never asserts drain
//          and valid_in together, but drain has priority if it did)
//
// Cycle behaviour, PIPE_MAC=0 (all updates on posedge clk):
//   rst                    : acc, valid_out, first_out <= 0
//   drain                  : acc <= acc_in
//   valid_in &  first_in   : acc <= a_in*b_in
//   valid_in & !first_in   : acc <= acc + a_in*b_in   (mod 2^ACC_W)
//   !valid_in              : acc holds (first_in ignored)
//   always (unless rst)    : a_out,b_out,valid_out,first_out <= *_in
//
// PIPE_MAC=1: same rules, but the accumulate step uses the previous cycle's
// operands and flags:
//   stage 1 (every edge)   : prod_q <= a_in*b_in      (data, no reset)
//                            valid_out/first_out <= valid_in/first_in  (as above)
//   stage 2                : drain                -> acc <= acc_in
//                            valid_out & first_out  -> acc <= prod_q
//                            valid_out & !first_out -> acc <= acc + prod_q
//                            !valid_out             -> acc holds
//   rst clears valid_out, so a product in flight at reset is discarded.
//   The caller must not assert drain while a product is still in stage 1
//   (the controller waits one extra cycle); drain would overwrite it.
//
// Latency: forwarded outputs 1 cycle; acc_out shows the new sum 1 + PIPE_MAC
// cycles after the operands are presented.

`timescale 1ns/1ps

module pe #(
    parameter int DATA_W = 8,    // operand width (signed)
    parameter int ACC_W  = 32,   // accumulator width (signed), must be >= 2*DATA_W
    parameter bit PIPE_MAC = 1'b1  // D-016: 1 = register the product (2-stage MAC)
) (
    input  logic                     clk,
    input  logic                     rst,

    input  logic signed [DATA_W-1:0] a_in,
    input  logic signed [DATA_W-1:0] b_in,
    input  logic                     valid_in,
    input  logic                     first_in,

    input  logic                     drain,    // D-013: shift acc down the column
    input  logic signed [ACC_W-1:0]  acc_in,   // acc_out of the PE above (0 for row 0)

    output logic signed [DATA_W-1:0] a_out,
    output logic signed [DATA_W-1:0] b_out,
    output logic                     valid_out,
    output logic                     first_out,

    output logic signed [ACC_W-1:0]  acc_out
);
    localparam int PROD_W = 2 * DATA_W;  // INT8*INT8 needs 16 bits: range [-16256, 16384]

    // ---------------- combinational datapath ----------------
    logic signed [PROD_W-1:0] prod;      // a*b, full precision
    logic signed [ACC_W-1:0]  acc;       // accumulator register
    logic signed [ACC_W-1:0]  acc_next;
    logic                     acc_en;    // accumulate on this edge

    // Both operands are declared signed, so this is a signed multiply.
    // (If either were unsigned, SV would treat the whole multiply as unsigned.)
    assign prod = a_in * b_in;

    if (PIPE_MAC) begin : g_pipe
        // Stage 1: product register. Stage 2 uses it with the registered flags.
        logic signed [PROD_W-1:0] prod_q;
        logic signed [ACC_W-1:0]  prod_ext;

        always_ff @(posedge clk) prod_q <= prod;   // data: no reset (valid_out gates it)

        assign prod_ext = {{(ACC_W-PROD_W){prod_q[PROD_W-1]}}, prod_q};
        // `first` selects AFTER the adder: the flag comes from a high-fanout,
        // buffered net, so keep it next to the flop instead of in front of
        // the carry chain. Same value as (first ? 0 : acc) + prod.
        assign acc_next = first_out ? prod_ext : acc + prod_ext;   // D-005, D-006
        assign acc_en   = valid_out;                               // D-008
    end else begin : g_single
        // Single-cycle MAC (D-009), unchanged from the original PE.
        logic signed [ACC_W-1:0] prod_ext;
        logic signed [ACC_W-1:0] addend;   // 0 at the start of a job, else acc

        assign prod_ext = {{(ACC_W-PROD_W){prod[PROD_W-1]}}, prod};  // explicit sign extension
        assign addend   = first_in ? '0 : acc;                       // D-005: no separate clear
        assign acc_next = addend + prod_ext;                         // D-006: ACC_W-bit add wraps
        assign acc_en   = valid_in;                                  // D-008
    end

    // ---------------- registers ----------------
    // Control flags and the accumulator are reset. The forwarded data registers
    // (a_out/b_out, and prod_q) are not: their values don't matter while valid
    // is low, and flops without reset are smaller and leave the reset net with
    // less fanout.
    always_ff @(posedge clk) begin
        if (rst) begin
            acc       <= '0;
            valid_out <= 1'b0;
            first_out <= 1'b0;
        end else begin
            if (drain)       acc <= acc_in;    // D-013: drain shift has priority
            else if (acc_en) acc <= acc_next;  // D-008: hold when not valid
            valid_out <= valid_in;
            first_out <= first_in;
        end
    end

    always_ff @(posedge clk) begin
        a_out <= a_in;
        b_out <= b_in;
    end

    assign acc_out = acc;

endmodule
