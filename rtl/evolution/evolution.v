`timescale 1ns / 1ps
// evolution.v — item counter (Mealy, FSM 2.3) + evolution form (Moore, FSM 2.4)
// HORSE --3 items--> BIKE --3 items--> BENZ (max in this demo)
module evolution #(
    parameter [1:0] THRESHOLD = 2'd3
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       collect,      // 1-clock pulse from item slots
    output reg  [1:0] form,         // 0 HORSE, 1 BIKE, 2 BENZ  (Moore: = state)
    output reg  [1:0] count,        // items collected toward next form
    output reg  [7:0] total,        // all items collected
    output wire       evolve        // Mealy: collect while count = THRESHOLD-1 and not max form
);
    localparam F_HORSE = 2'd0, F_BIKE = 2'd1, F_BENZ = 2'd2;

    assign evolve = collect && (count == THRESHOLD - 2'd1) && (form != F_BENZ);

    always @(posedge clk) begin
        if (rst) begin
            form <= F_HORSE; count <= 2'd0; total <= 8'd0;
        end else if (collect) begin
            total <= total + 8'd1;
            if (evolve) begin
                count <= 2'd0;
                form  <= form + 2'd1;                    // HORSE->BIKE->BENZ
            end else if (count != THRESHOLD) begin
                count <= count + 2'd1;                   // at BENZ saturates at 3
            end
        end
    end
endmodule
