`timescale 1ns / 1ps
// kbd_decoder.v — Scan-code set 2 -> key-held state (Mealy FSM, see docs FSM 1.2)
// Supports WASD and arrow keys (E0-prefixed). Output updates on the transition
// that consumes the make/break code, depending on state + received byte (Mealy).
module kbd_decoder (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] rx_byte,
    input  wire       rx_done,
    output wire       key_up,
    output wire       key_down,
    output wire       key_left,
    output wire       key_right
);
    localparam S_WAIT = 2'd0, S_BREAK = 2'd1, S_EXT = 2'd2, S_EXT_BREAK = 2'd3;
    reg [1:0] state;

    reg k_w, k_a, k_s, k_d;          // WASD
    reg k_au, k_al, k_ad, k_ar;      // arrows

    assign key_up    = k_w | k_au;
    assign key_left  = k_a | k_al;
    assign key_down  = k_s | k_ad;
    assign key_right = k_d | k_ar;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_WAIT;
            {k_w, k_a, k_s, k_d, k_au, k_al, k_ad, k_ar} <= 8'd0;
        end else if (rx_done) begin
            case (state)
            S_WAIT: begin
                if (rx_byte == 8'hF0)      state <= S_BREAK;
                else if (rx_byte == 8'hE0) state <= S_EXT;
                else begin
                    case (rx_byte)                       // make code / key := 1
                        8'h1D: k_w <= 1'b1;
                        8'h1C: k_a <= 1'b1;
                        8'h1B: k_s <= 1'b1;
                        8'h23: k_d <= 1'b1;
                        default: ;
                    endcase
                end
            end
            S_BREAK: begin                                // break code / key := 0
                case (rx_byte)
                    8'h1D: k_w <= 1'b0;
                    8'h1C: k_a <= 1'b0;
                    8'h1B: k_s <= 1'b0;
                    8'h23: k_d <= 1'b0;
                    default: ;
                endcase
                state <= S_WAIT;
            end
            S_EXT: begin
                if (rx_byte == 8'hF0) state <= S_EXT_BREAK;
                else begin
                    case (rx_byte)
                        8'h75: k_au <= 1'b1;
                        8'h6B: k_al <= 1'b1;
                        8'h72: k_ad <= 1'b1;
                        8'h74: k_ar <= 1'b1;
                        default: ;
                    endcase
                    state <= S_WAIT;
                end
            end
            S_EXT_BREAK: begin
                case (rx_byte)
                    8'h75: k_au <= 1'b0;
                    8'h6B: k_al <= 1'b0;
                    8'h72: k_ad <= 1'b0;
                    8'h74: k_ar <= 1'b0;
                    default: ;
                endcase
                state <= S_WAIT;
            end
            endcase
        end
    end
endmodule
