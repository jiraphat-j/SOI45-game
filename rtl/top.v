`timescale 1ns / 1ps
// top.v — SOI 45: Evolution Rush, progress demo (CPE222, Nexys A7)
// Feature 1: 8-direction movement, sprite per direction, road boundary clamp
// Feature 2: collect items -> item sparkles & disappears -> counter -> evolve HORSE->BIKE->BENZ
// Inputs : USB keyboard (WASD / arrows) through the on-board PS/2 bridge, or BTNU/BTND/BTNL/BTNR
// Outputs: VGA 640x480@60, LED, RGB LED16, 8-digit 7-segment
module top (
    input  wire        CLK100MHZ,
    input  wire        CPU_RESETN,
    input  wire        BTNU, BTND, BTNL, BTNR,
    input  wire        PS2_CLK,
    input  wire        PS2_DATA,
    output reg  [3:0]  VGA_R,
    output reg  [3:0]  VGA_G,
    output reg  [3:0]  VGA_B,
    output reg         VGA_HS,
    output reg         VGA_VS,
    output wire [15:0] LED,
    output wire        LED16_R, LED16_G, LED16_B,
    output wire [6:0]  SEG,
    output wire        DP,
    output wire [7:0]  AN
);
    wire clk = CLK100MHZ;

    // ---------------- reset & pixel enable ----------------
    reg [1:0] rst_sync = 2'b11;
    always @(posedge clk) rst_sync <= {rst_sync[0], ~CPU_RESETN};
    wire rst = rst_sync[1];

    reg [1:0] pdiv = 2'd0;
    always @(posedge clk) pdiv <= pdiv + 2'd1;
    wire pix_en = (pdiv == 2'd3);                 // 25 MHz

    wire [9:0] x, y;
    wire hs, vs, video_on, frame_tick;
    vga_sync u_vga (.clk(clk), .rst(rst), .pix_en(pix_en), .x(x), .y(y),
                    .hs(hs), .vs(vs), .video_on(video_on), .frame_tick(frame_tick));

    // ---------------- inputs ----------------
    wire [7:0] rx_byte;
    wire       rx_done;
    wire       k_up, k_down, k_left, k_right;
    ps2_rx      u_ps2 (.clk(clk), .rst(rst), .ps2_clk(PS2_CLK), .ps2_data(PS2_DATA),
                       .rx_byte(rx_byte), .rx_done(rx_done));
    kbd_decoder u_kbd (.clk(clk), .rst(rst), .rx_byte(rx_byte), .rx_done(rx_done),
                       .key_up(k_up), .key_down(k_down), .key_left(k_left), .key_right(k_right));

    wire b_up, b_down, b_left, b_right;
    debounce u_db_u (.clk(clk), .rst(rst), .btn_in(BTNU), .btn_out(b_up));
    debounce u_db_d (.clk(clk), .rst(rst), .btn_in(BTND), .btn_out(b_down));
    debounce u_db_l (.clk(clk), .rst(rst), .btn_in(BTNL), .btn_out(b_left));
    debounce u_db_r (.clk(clk), .rst(rst), .btn_in(BTNR), .btn_out(b_right));

    wire in_up    = k_up    | b_up;
    wire in_down  = k_down  | b_down;
    wire in_left  = k_left  | b_left;
    wire in_right = k_right | b_right;
    // opposite directions cancel
    wire mv_up    = in_up    & ~in_down;
    wire mv_down  = in_down  & ~in_up;
    wire mv_left  = in_left  & ~in_right;
    wire mv_right = in_right & ~in_left;

    // ---------------- Feature 1: movable ----------------
    wire [1:0] form;
    wire [2:0] dir;
    wire [9:0] px, py;
    wire [3:0] spd;
    facing_fsm  u_face (.clk(clk), .rst(rst), .tick(frame_tick),
                        .mv_up(mv_up), .mv_down(mv_down), .mv_left(mv_left), .mv_right(mv_right),
                        .dir(dir));
    player_move u_move (.clk(clk), .rst(rst), .tick(frame_tick),
                        .mv_up(mv_up), .mv_down(mv_down), .mv_left(mv_left), .mv_right(mv_right),
                        .form(form), .px(px), .py(py), .spd(spd));

    // ---------------- Feature 2: items & evolution ----------------
    wire [15:0] rnd;
    lfsr16 u_lfsr (.clk(clk), .rst(rst), .q(rnd));

    wire [9:0] ix0, iy0, ix1, iy1, ix2, iy2;
    wire ov0, ov1, ov2, vis0, vis1, vis2, pop0, pop1, pop2, col0, col1, col2;
    wire evolve;
    // priority arbiter: at most one item collected per frame
    wire g0 = ov0;
    wire g1 = ov1 & ~ov0;
    wire g2 = ov2 & ~ov0 & ~ov1;

    item_slot #(.INIT_WAIT(7'd80)) u_it0 (.clk(clk), .rst(rst), .tick(frame_tick), .px(px), .py(py),
        .grant(g0), .clear(evolve), .rnd(rnd),
        .ix(ix0), .iy(iy0), .overlap(ov0), .visible(vis0), .popping(pop0), .collect(col0));
    item_slot #(.INIT_WAIT(7'd50)) u_it1 (.clk(clk), .rst(rst), .tick(frame_tick), .px(px), .py(py),
        .grant(g1), .clear(evolve), .rnd({rnd[7:0], rnd[15:8]}),
        .ix(ix1), .iy(iy1), .overlap(ov1), .visible(vis1), .popping(pop1), .collect(col1));
    item_slot #(.INIT_WAIT(7'd20)) u_it2 (.clk(clk), .rst(rst), .tick(frame_tick), .px(px), .py(py),
        .grant(g2), .clear(evolve), .rnd(~{rnd[3:0], rnd[15:4]}),
        .ix(ix2), .iy(iy2), .overlap(ov2), .visible(vis2), .popping(pop2), .collect(col2));

    wire [1:0] count;
    wire [7:0] total;
    evolution u_evo (.clk(clk), .rst(rst), .collect(col0 | col1 | col2),
                     .form(form), .count(count), .total(total), .evolve(evolve));

    // ---------------- road scroll ----------------
    reg [9:0] scroll;
    always @(posedge clk) begin
        if (rst) scroll <= 10'd0;
        else if (frame_tick) scroll <= scroll + {6'd0, spd};
    end

    // ---------------- renderer ----------------
    // Counters x,y are stable for 4 clocks per pixel; ROM data is ready 1 clock after the address.
    // At pix_en we register RGB + sync from the same (pre-increment) x,y, so they stay aligned.
    wire [9:0] prx = x - px, pry = y - py;
    wire p_in = (x >= px) && (x < px + 10'd32) && (y >= py) && (y < py + 10'd32);
    wire [3:0] p_idx;
    sprite_rom #(.AW(15), .MEMFILE("player.mem")) u_prom (.clk(clk),
        .addr({form, dir, pry[4:0], prx[4:0]}), .data(p_idx));

    // item frames: 0 = motorcycle token, 1 = benz token, 2 = star (max form), 3 = sparkle
    wire [1:0] item_kind = (form == 2'd0) ? 2'd0 : (form == 2'd1) ? 2'd1 : 2'd2;

    wire [9:0] i0rx = x - ix0, i0ry = y - iy0;
    wire [9:0] i1rx = x - ix1, i1ry = y - iy1;
    wire [9:0] i2rx = x - ix2, i2ry = y - iy2;
    wire i0_in = vis0 && (x >= ix0) && (x < ix0 + 10'd32) && (y >= iy0) && (y < iy0 + 10'd32);
    wire i1_in = vis1 && (x >= ix1) && (x < ix1 + 10'd32) && (y >= iy1) && (y < iy1 + 10'd32);
    wire i2_in = vis2 && (x >= ix2) && (x < ix2 + 10'd32) && (y >= iy2) && (y < iy2 + 10'd32);
    wire [3:0] i0_idx, i1_idx, i2_idx;
    sprite_rom #(.AW(12), .MEMFILE("item.mem")) u_irom0 (.clk(clk),
        .addr({pop0 ? 2'd3 : item_kind, i0ry[4:0], i0rx[4:0]}), .data(i0_idx));
    sprite_rom #(.AW(12), .MEMFILE("item.mem")) u_irom1 (.clk(clk),
        .addr({pop1 ? 2'd3 : item_kind, i1ry[4:0], i1rx[4:0]}), .data(i1_idx));
    sprite_rom #(.AW(12), .MEMFILE("item.mem")) u_irom2 (.clk(clk),
        .addr({pop2 ? 2'd3 : item_kind, i2ry[4:0], i2rx[4:0]}), .data(i2_idx));

    // background: grass | road with edge lines and scrolling lane dashes
    wire [9:0] sy = y - scroll;
    reg  [3:0] bg_idx;
    always @(*) begin
        if (x < 10'd128 || x >= 10'd512)                   bg_idx = sy[5] ? 4'h9 : 4'hA;
        else if (x < 10'd132 || x >= 10'd508)              bg_idx = 4'h5;
        else if (((x >= 10'd254 && x < 10'd258) || (x >= 10'd382 && x < 10'd386)) && !sy[5])
                                                           bg_idx = 4'h4;
        else                                               bg_idx = 4'h2;
    end

    // HUD (y < 48): 3 count boxes on the left, 3 form boxes on the right
    reg [3:0] hud_idx;
    wire hud_row = (y >= 10'd12) && (y < 10'd36);
    always @(*) begin
        hud_idx = 4'h1;
        if (hud_row) begin
            // count boxes at x = 16, 44, 72 (24 wide)
            if (x >= 10'd16 && x < 10'd40)       hud_idx = (count > 2'd0) ? 4'h8 : 4'h3;
            else if (x >= 10'd44 && x < 10'd68)  hud_idx = (count > 2'd1) ? 4'h8 : 4'h3;
            else if (x >= 10'd72 && x < 10'd96)  hud_idx = (count > 2'd2) ? 4'h8 : 4'h3;
            // form boxes at x = 544, 572, 600
            else if (x >= 10'd544 && x < 10'd568) hud_idx = (form == 2'd0) ? 4'hD : 4'h2;
            else if (x >= 10'd572 && x < 10'd596) hud_idx = (form == 2'd1) ? 4'hB : 4'h2;
            else if (x >= 10'd600 && x < 10'd624) hud_idx = (form == 2'd2) ? 4'h4 : 4'h2;
        end
        if (y == 10'd47) hud_idx = 4'h5;                    // divider line
    end

    reg [3:0] pix_idx;
    always @(*) begin
        if (y < 10'd48)                  pix_idx = hud_idx;
        else if (p_in  && p_idx  != 4'h0) pix_idx = p_idx;
        else if (i0_in && i0_idx != 4'h0) pix_idx = i0_idx;
        else if (i1_in && i1_idx != 4'h0) pix_idx = i1_idx;
        else if (i2_in && i2_idx != 4'h0) pix_idx = i2_idx;
        else                             pix_idx = bg_idx;
    end

    wire [11:0] rgb;
    palette u_pal (.idx(pix_idx), .rgb(rgb));

    always @(posedge clk) begin
        if (pix_en) begin
            VGA_HS <= hs;
            VGA_VS <= vs;
            if (video_on) {VGA_R, VGA_G, VGA_B} <= rgb;
            else          {VGA_R, VGA_G, VGA_B} <= 12'h000;
        end
    end

    // ---------------- LEDs / 7-segment ----------------
    // LED[2:0]  item count (thermometer)       LED[11:8] keyboard up/down/left/right (debug)
    // LED[15:13] form one-hot HORSE/BIKE/BENZ   LED[7] any PS/2 byte received (toggle)
    reg rx_toggle;
    always @(posedge clk) if (rst) rx_toggle <= 1'b0; else if (rx_done) rx_toggle <= ~rx_toggle;

    assign LED[2:0]   = {count > 2'd2, count > 2'd1, count > 2'd0};
    assign LED[6:3]   = 4'b0;
    assign LED[7]     = rx_toggle;
    assign LED[11:8]  = {k_up, k_down, k_left, k_right};
    assign LED[12]    = 1'b0;
    assign LED[15:13] = {form == 2'd2, form == 2'd1, form == 2'd0};

    // RGB LED16 shows the form colour, dimmed to 1/16 duty (full brightness is very bright)
    // HORSE = yellow (R+G), BIKE = blue, BENZ = green
    reg [3:0] pwm_cnt;
    always @(posedge clk) pwm_cnt <= pwm_cnt + 4'd1;
    wire dim = (pwm_cnt == 4'd0);
    assign LED16_R = dim & (form == 2'd0);
    assign LED16_G = dim & ((form == 2'd0) || (form == 2'd2));
    assign LED16_B = dim & (form == 2'd1);

    seg7_scan u_seg (.clk(clk), .rst(rst), .form(form), .count(count), .total(total),
                     .seg(SEG), .dp(DP), .an(AN));
endmodule
