`timescale 1ns / 1ps
// ps2_rx.v — PS/2 byte receiver (Moore FSM, see docs FSM 1.1)
// Nexys A7: the PIC24 USB-HID host emulates a PS/2 keyboard on PS2_CLK / PS2_DATA.
// Frame: start(0), 8 data bits LSB first, odd parity, stop(1). Sample on falling edge of PS2_CLK.
module ps2_rx (
    input  wire       clk,       // 100 MHz
    input  wire       rst,
    input  wire       ps2_clk,
    input  wire       ps2_data,
    output reg  [7:0] rx_byte,
    output wire       rx_done    // 1-clock pulse (Moore: asserted in DONE)
);
    // 2-FF synchronizers
    reg [1:0] clk_sync, dat_sync;
    always @(posedge clk) begin
        clk_sync <= {clk_sync[0], ps2_clk};
        dat_sync <= {dat_sync[0], ps2_data};
    end

    // glitch filter on PS2 clock (8 equal samples)
    reg [7:0] filt;
    reg       fclk, fclk_d;
    always @(posedge clk) begin
        if (rst) begin
            filt <= 8'hFF; fclk <= 1'b1; fclk_d <= 1'b1;
        end else begin
            filt   <= {filt[6:0], clk_sync[1]};
            if (&filt)      fclk <= 1'b1;
            else if (~|filt) fclk <= 1'b0;
            fclk_d <= fclk;
        end
    end
    wire negedge_ps2 = fclk_d & ~fclk;

    localparam S_IDLE = 2'd0, S_RECV = 2'd1, S_DONE = 2'd2;
    reg [1:0]  state;
    reg [3:0]  nbit;      // bits received after start
    reg [9:0]  shreg;     // data[7:0], parity, stop  (shift right)
    reg [17:0] timeout;   // ~2.6 ms at 100 MHz

    assign rx_done = (state == S_DONE);

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE; nbit <= 4'd0; shreg <= 10'd0; timeout <= 18'd0; rx_byte <= 8'd0;
        end else begin
            case (state)
            S_IDLE: begin
                nbit <= 4'd0; timeout <= 18'd0;
                if (negedge_ps2 && dat_sync[1] == 1'b0)   // start bit
                    state <= S_RECV;
            end
            S_RECV: begin
                if (negedge_ps2) begin
                    timeout <= 18'd0;
                    shreg   <= {dat_sync[1], shreg[9:1]};
                    nbit    <= nbit + 4'd1;
                    if (nbit == 4'd9) begin
                        // this edge carries the stop bit; data = shreg[8:1], parity = shreg[9]
                        rx_byte <= shreg[8:1];
                        if (dat_sync[1] == 1'b1 && (^shreg[9:1]) == 1'b1)  // stop ok, odd parity ok
                            state <= S_DONE;
                        else
                            state <= S_IDLE;
                    end
                end else begin
                    timeout <= timeout + 18'd1;
                    if (&timeout) state <= S_IDLE;   // lost sync
                end
            end
            S_DONE:  state <= S_IDLE;
            default: state <= S_IDLE;
            endcase
        end
    end
endmodule
