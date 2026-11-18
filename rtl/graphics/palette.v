`timescale 1ns / 1ps
// palette.v — shared 16-colour palette (4-bit index -> RGB444). Index 0 = transparent.
module palette (
    input  wire [3:0]  idx,
    output reg  [11:0] rgb
);
    always @(*) begin
        case (idx)
            4'h0: rgb = 12'h000;  // transparent
            4'h1: rgb = 12'h112;  // ink
            4'h2: rgb = 12'h345;  // asphalt
            4'h3: rgb = 12'h667;  // grey
            4'h4: rgb = 12'hBBC;  // silver
            4'h5: rgb = 12'hFFF;  // white
            4'h6: rgb = 12'hD44;  // red
            4'h7: rgb = 12'hF83;  // orange
            4'h8: rgb = 12'hFD6;  // yellow
            4'h9: rgb = 12'h485;  // grass dark
            4'hA: rgb = 12'h7B8;  // grass light
            4'hB: rgb = 12'h47B;  // blue
            4'hC: rgb = 12'h8CE;  // sky / glass
            4'hD: rgb = 12'h853;  // brown
            4'hE: rgb = 12'hCA8;  // skin / sand
            4'hF: rgb = 12'h957;  // plum
        endcase
    end
endmodule
