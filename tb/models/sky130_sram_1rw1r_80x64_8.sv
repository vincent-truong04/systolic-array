// Behavioral model of the OpenRAM macro sky130_sram_1rw1r_80x64_8 for RTL simulation (D-018).
// SIMULATION ONLY. Synthesis/PD use the macro's LEF/LIB/GDS (black box); this file is never
// given to Yosys.
//
// Same ports and cycle behavior as the OpenRAM model
// (~/OpenROAD-flow-scripts/flow/platforms/sky130ram/sky130_sram_1rw1r_80x64_8/*.v):
//   - all inputs captured at posedge
//   - write (port 0) happens at the following negedge, per 8-bit lane of wmask0
//   - read data appears at the following negedge
// Differences (on purpose, documented):
//   - no $display on every access (the OpenRAM model logs each read/write)
//   - no #DELAY and no "dout = X right after posedge": dout holds its value until the next
//     read's negedge. Real read data is valid only from ~negedge to the next posedge; the
//     wrapper captures it at exactly that posedge, so holding it longer hides nothing the
//     RTL relies on. Hold timing at that capture is STA's job (macro .lib), not this model's.
//   - a same-edge write + read of one address is an error here (undefined in OpenRAM).

`timescale 1ns/1ps

module sky130_sram_1rw1r_80x64_8 (
    input  logic        clk0,
    input  logic        csb0,
    input  logic        web0,
    input  logic [9:0]  wmask0,
    input  logic [5:0]  addr0,
    input  logic [79:0] din0,
    output logic [79:0] dout0,
    input  logic        clk1,
    input  logic        csb1,
    input  logic [5:0]  addr1,
    output logic [79:0] dout1
);
    logic [79:0] mem [64];

    logic        csb0_r, web0_r, csb1_r;
    logic [9:0]  wmask0_r;
    logic [5:0]  addr0_r, addr1_r;
    logic [79:0] din0_r;

    always_ff @(posedge clk0) begin
        csb0_r   <= csb0;
        web0_r   <= web0;
        wmask0_r <= wmask0;
        addr0_r  <= addr0;
        din0_r   <= din0;
    end

    always_ff @(posedge clk1) begin
        csb1_r  <= csb1;
        addr1_r <= addr1;
        if (!csb0 && !web0 && !csb1 && addr0 == addr1)
            $error("sram model: write and read of addr %0d at the same edge (undefined)", addr0);
    end

    // port 0: write per lane / read at negedge
    always_ff @(negedge clk0) begin
        if (!csb0_r && !web0_r) begin
            for (int l = 0; l < 10; l++)
                if (wmask0_r[l]) mem[addr0_r][l*8 +: 8] <= din0_r[l*8 +: 8];
        end
        if (!csb0_r && web0_r) dout0 <= mem[addr0_r];
    end

    // port 1: read at negedge
    always_ff @(negedge clk1) begin
        if (!csb1_r) dout1 <= mem[addr1_r];
    end
endmodule
