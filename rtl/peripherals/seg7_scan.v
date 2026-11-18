`timescale 1ns / 1ps
// seg7_scan.v — 8-digit multiplexed 7-segment driver (ring-counter Moore FSM, see docs 3.2)
// Nexys A7: cathodes CA..CG and anodes AN[7:0] are active LOW.
// Layout:  [F][form] [ ][ ] [C][count] [total hi][total lo]
module seg7_scan (
    input  wire       clk,
    input  wire       rst,
    input  wire [1:0] form,
    input  wire [1:0] count,
    input  wire [7:0] total,
    output reg  [6:0] seg,     // {g,f,e,d,c,b,a}
    output wire       dp,
    output reg  [7:0] an
);
    reg [19:0] div;
    always @(posedge clk) div <= rst ? 20'd0 : div + 20'd1;
    wire [2:0] digit = div[19:17];          // ~763 Hz per digit, ~95 Hz full refresh

    // 5-bit code: 0-15 hex, 16 = blank
    reg [4:0] code;
    always @(*) begin
        case (digit)
            3'd0: code = {1'b0, total[3:0]};
            3'd1: code = {1'b0, total[7:4]};
            3'd2: code = {3'b000, count};
            3'd3: code = 5'h0C;                       // 'C'
            3'd4: code = 5'h10;
            3'd5: code = 5'h10;
            3'd6: code = {3'b000, form} + 5'd1;       // 1..3
            3'd7: code = 5'h0F;                       // 'F'
        endcase
    end

    always @(*) begin
        an = ~(8'b1 << digit);
        case (code)
            5'h00: seg = 7'b1000000;
            5'h01: seg = 7'b1111001;
            5'h02: seg = 7'b0100100;
            5'h03: seg = 7'b0110000;
            5'h04: seg = 7'b0011001;
            5'h05: seg = 7'b0010010;
            5'h06: seg = 7'b0000010;
            5'h07: seg = 7'b1111000;
            5'h08: seg = 7'b0000000;
            5'h09: seg = 7'b0010000;
            5'h0A: seg = 7'b0001000;
            5'h0B: seg = 7'b0000011;
            5'h0C: seg = 7'b1000110;
            5'h0D: seg = 7'b0100001;
            5'h0E: seg = 7'b0000110;
            5'h0F: seg = 7'b0001110;
            default: seg = 7'b1111111;                // blank
        endcase
    end
    assign dp = 1'b1;   // off
endmodule
