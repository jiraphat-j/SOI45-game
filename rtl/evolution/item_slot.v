`timescale 1ns / 1ps
// item_slot.v — one collectible item: AABB collision + lifecycle (Moore FSM, see docs FSM 2.1/2.2)
// GONE --(respawn timer)--> ACTIVE --(granted hit)--> HIT (collect=1, 1 clk) --> POP (sparkle) --> GONE
module item_slot #(
    parameter [6:0] INIT_WAIT = 7'd30,   // first spawn delay (frames), stagger per slot
    parameter [6:0] POP_T     = 7'd20,   // sparkle frames
    parameter [6:0] RESPAWN_T = 7'd90    // frames hidden before respawn
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        tick,
    input  wire [9:0]  px,          // player top-left (32x32)
    input  wire [9:0]  py,
    input  wire        grant,       // this slot may consume its overlap (priority arbiter in top)
    input  wire        clear,       // evolve: hide all items
    input  wire [15:0] rnd,
    output reg  [9:0]  ix,          // item top-left (32x32 canvas, 24x24 hitbox)
    output reg  [9:0]  iy,
    output wire        overlap,     // ACTIVE & AABB
    output wire        visible,
    output wire        popping,     // draw sparkle frame
    output wire        collect      // 1-clock pulse
);
    localparam I_GONE = 2'd0, I_ACTIVE = 2'd1, I_HIT = 2'd2, I_POP = 2'd3;
    reg [1:0] state;
    reg [6:0] t;

    // hitboxes: player [p+4, p+28), item [i+4, i+28)
    function aabb;
        input [9:0] ax, ay, bx, by;
        begin
            aabb = (ax + 10'd4 < bx + 10'd28) && (bx + 10'd4 < ax + 10'd28) &&
                   (ay + 10'd4 < by + 10'd28) && (by + 10'd4 < ay + 10'd28);
        end
    endfunction

    assign overlap = (state == I_ACTIVE) && aabb(px, py, ix, iy);
    assign visible = (state == I_ACTIVE) || (state == I_HIT) || (state == I_POP);
    assign popping = (state == I_HIT) || (state == I_POP);
    assign collect = (state == I_HIT);

    // candidate spawn position inside the road: x 128..480, y 56..448
    wire [8:0] rx9 = rnd[8:0];
    wire [8:0] ry9 = rnd[15:7];
    wire [9:0] cand_x = 10'd128 + ((rx9 > 9'd352) ? {1'b0, rx9} - 10'd256 : {1'b0, rx9});
    wire [9:0] cand_y = 10'd56  + ((ry9 > 9'd392) ? {1'b0, ry9} - 10'd256 : {1'b0, ry9});
    // keep a margin so the item never spawns on top of the player
    wire near_player = (cand_x + 10'd48 > px) && (px + 10'd48 > cand_x) &&
                       (cand_y + 10'd48 > py) && (py + 10'd48 > cand_y);

    always @(posedge clk) begin
        if (rst) begin
            state <= I_GONE; t <= RESPAWN_T - INIT_WAIT; ix <= 10'd304; iy <= 10'd100;
        end else if (clear && state == I_ACTIVE) begin   // the collected item keeps its sparkle
            state <= I_GONE; t <= 7'd0;
        end else begin
            case (state)
            I_GONE: if (tick) begin
                if (t >= RESPAWN_T) begin
                    if (!near_player) begin
                        ix <= cand_x; iy <= cand_y; state <= I_ACTIVE;
                    end                      // else retry next frame with a new random value
                end else t <= t + 7'd1;
            end
            I_ACTIVE: if (tick && grant) begin state <= I_HIT; t <= 7'd0; end
            I_HIT:    state <= I_POP;
            I_POP: if (tick) begin
                if (t >= POP_T) begin state <= I_GONE; t <= 7'd0; end
                else t <= t + 7'd1;
            end
            endcase
        end
    end
endmodule
