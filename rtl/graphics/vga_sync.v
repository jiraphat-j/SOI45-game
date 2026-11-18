`timescale 1ns / 1ps
// vga_sync.v — 640x480 @ 60 Hz timing (counter-based Moore FSM, see docs 3.1)
// Pixel clock 25 MHz realised as a clock-enable (pix_en) from 100 MHz.
module vga_sync (
    input  wire       clk,
    input  wire       rst,
    input  wire       pix_en,
    output reg  [9:0] x,
    output reg  [9:0] y,
    output wire       hs,         // active low
    output wire       vs,         // active low
    output wire       video_on,
    output wire       frame_tick  // 1 clk at start of vertical blanking (x=0, y=480)
);
    localparam H_VIS = 640, H_FP = 16, H_SYNC = 96, H_BP = 48, H_TOT = 800;
    localparam V_VIS = 480, V_FP = 10, V_SYNC = 2,  V_BP = 33, V_TOT = 525;

    always @(posedge clk) begin
        if (rst) begin
            x <= 10'd0; y <= 10'd0;
        end else if (pix_en) begin
            if (x == H_TOT - 1) begin
                x <= 10'd0;
                y <= (y == V_TOT - 1) ? 10'd0 : y + 10'd1;
            end else begin
                x <= x + 10'd1;
            end
        end
    end

    assign hs = ~((x >= H_VIS + H_FP) && (x < H_VIS + H_FP + H_SYNC));
    assign vs = ~((y >= V_VIS + V_FP) && (y < V_VIS + V_FP + V_SYNC));
    assign video_on   = (x < H_VIS) && (y < V_VIS);
    assign frame_tick = pix_en && (x == 10'd0) && (y == V_VIS);
endmodule
