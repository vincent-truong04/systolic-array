// Second simulation root for SDF gate-level runs: back-annotates the delays
// written by OpenSTA (write_sdf) onto the systolic_top netlist instance.
`timescale 1ns/1ps
module sdf_annotate;
    initial $sdf_annotate(`SDF_FILE, systolic_top);
endmodule
