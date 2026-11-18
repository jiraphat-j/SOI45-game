`timescale 1ns / 1ps
// sprite_rom.v — synchronous ROM (infers Block RAM), 4-bit palette index per pixel
// player.mem : addr = {form[1:0], dir[2:0], row[4:0], col[4:0]}  (32768 x 4)
// item.mem   : addr = {frame[1:0], row[4:0], col[4:0]}           (4096 x 4)
module sprite_rom #(
    parameter AW = 15,
    parameter MEMFILE = "player.mem"
) (
    input  wire          clk,
    input  wire [AW-1:0] addr,
    output reg  [3:0]    data
);
    (* rom_style = "block" *) reg [3:0] mem [0:(1<<AW)-1];
    initial $readmemh(MEMFILE, mem);
    always @(posedge clk) data <= mem[addr];
endmodule
