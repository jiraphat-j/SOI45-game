`timescale 1ns / 1ps
// facing_fsm.v — 8-direction facing state (Moore FSM, see docs FSM 1.4)
// State = facing direction; output dir selects the sprite frame.
// dir: 0=N 1=NE 2=E 3=SE 4=S 5=SW 6=W 7=NW. No input -> keep last direction.
module facing_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,      // frame_tick (60 Hz)
    input  wire       mv_up,     // already cancelled (up & ~down)
    input  wire       mv_down,
    input  wire       mv_left,
    input  wire       mv_right,
    output reg  [2:0] dir
);
    localparam N = 3'd0, NE = 3'd1, E = 3'd2, SE = 3'd3,
               S = 3'd4, SW = 3'd5, W = 3'd6, NW = 3'd7;

    reg [2:0] next;
    always @(*) begin
        case ({mv_up, mv_down, mv_left, mv_right})
            4'b1000: next = N;
            4'b1001: next = NE;
            4'b0001: next = E;
            4'b0101: next = SE;
            4'b0100: next = S;
            4'b0110: next = SW;
            4'b0010: next = W;
            4'b1010: next = NW;
            default: next = dir;           // (0,0): stay
        endcase
    end

    always @(posedge clk) begin
        if (rst)       dir <= S;           // start facing down (toward the player)
        else if (tick) dir <= next;
    end
endmodule
