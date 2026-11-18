`timescale 1ns / 1ps
// player_move.v — free XY movement + boundary clamp (Moore FSM, see docs FSM 1.5)
// Runs once per frame: WAIT -> MOVE -> CLAMP -> WAIT.
// Speed depends on form; diagonal uses ~0.707x per axis.
module player_move #(
    parameter X_MIN = 128, parameter X_MAX = 480,   // road 128..511, sprite 32 wide
    parameter Y_MIN = 48,  parameter Y_MAX = 448,   // below HUD, sprite 32 tall
    parameter X_START = 304, parameter Y_START = 400
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       tick,
    input  wire       mv_up,
    input  wire       mv_down,
    input  wire       mv_left,
    input  wire       mv_right,
    input  wire [1:0] form,        // 0 horse, 1 bike, 2 benz
    output reg  [9:0] px,
    output reg  [9:0] py,
    output reg  [3:0] spd          // straight speed of current form (for road scroll)
);
    reg [3:0] spd_diag;
    always @(*) begin
        case (form)
            2'd0:    begin spd = 4'd3; spd_diag = 4'd2; end   // horse
            2'd1:    begin spd = 4'd5; spd_diag = 4'd4; end   // motorcycle
            2'd2:    begin spd = 4'd4; spd_diag = 4'd3; end   // benz
            default: begin spd = 4'd3; spd_diag = 4'd2; end
        endcase
    end

    wire        diag = (mv_up | mv_down) & (mv_left | mv_right);
    wire [3:0]  step = diag ? spd_diag : spd;

    localparam P_WAIT = 2'd0, P_MOVE = 2'd1, P_CLAMP = 2'd2;
    reg [1:0] state;
    reg signed [11:0] nx, ny;

    always @(posedge clk) begin
        if (rst) begin
            state <= P_WAIT; px <= X_START; py <= Y_START;
            nx <= X_START; ny <= Y_START;
        end else begin
            case (state)
            P_WAIT:  if (tick) state <= P_MOVE;
            P_MOVE: begin
                nx <= $signed({2'b00, px}) + (mv_right ? $signed({8'd0, step}) : 12'sd0)
                                           - (mv_left  ? $signed({8'd0, step}) : 12'sd0);
                ny <= $signed({2'b00, py}) + (mv_down  ? $signed({8'd0, step}) : 12'sd0)
                                           - (mv_up    ? $signed({8'd0, step}) : 12'sd0);
                state <= P_CLAMP;
            end
            P_CLAMP: begin
                if (nx < X_MIN)      px <= X_MIN;
                else if (nx > X_MAX) px <= X_MAX;
                else                 px <= nx[9:0];
                if (ny < Y_MIN)      py <= Y_MIN;
                else if (ny > Y_MAX) py <= Y_MAX;
                else                 py <= ny[9:0];
                state <= P_WAIT;
            end
            default: state <= P_WAIT;
            endcase
        end
    end
endmodule
