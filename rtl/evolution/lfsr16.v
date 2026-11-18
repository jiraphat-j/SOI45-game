`timescale 1ns / 1ps
// lfsr16.v — 16-bit Fibonacci LFSR (x^16 + x^14 + x^13 + x^11 + 1), free running
module lfsr16 (
    input  wire        clk,
    input  wire        rst,
    output reg  [15:0] q
);
    wire fb = q[15] ^ q[13] ^ q[12] ^ q[10];
    always @(posedge clk) begin
        if (rst) q <= 16'hACE1;
        else     q <= {q[14:0], fb};
    end
endmodule
