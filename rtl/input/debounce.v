`timescale 1ns / 1ps
// debounce.v — push-button debouncer (Moore FSM, see docs FSM 1.3)
// Output changes only after the input has been stable for STABLE clocks (10 ms @ 100 MHz).
module debounce #(
    parameter STABLE = 1_000_000
) (
    input  wire clk,
    input  wire rst,
    input  wire btn_in,
    output wire btn_out
);
    reg [1:0] sync;
    always @(posedge clk) sync <= {sync[0], btn_in};
    wire in = sync[1];

    localparam RELEASED = 2'd0, WAIT_HI = 2'd1, PRESSED = 2'd2, WAIT_LO = 2'd3;
    reg [1:0]  state;
    reg [19:0] cnt;

    assign btn_out = (state == PRESSED) || (state == WAIT_LO);   // Moore output

    always @(posedge clk) begin
        if (rst) begin
            state <= RELEASED; cnt <= 20'd0;
        end else begin
            case (state)
            RELEASED: begin cnt <= 20'd0; if (in) state <= WAIT_HI; end
            WAIT_HI: begin
                if (!in) state <= RELEASED;
                else if (cnt == STABLE - 1) state <= PRESSED;
                else cnt <= cnt + 20'd1;
            end
            PRESSED: begin cnt <= 20'd0; if (!in) state <= WAIT_LO; end
            WAIT_LO: begin
                if (in) state <= PRESSED;
                else if (cnt == STABLE - 1) state <= RELEASED;
                else cnt <= cnt + 20'd1;
            end
            endcase
        end
    end
endmodule
