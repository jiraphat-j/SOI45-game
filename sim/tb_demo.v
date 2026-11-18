// tb_demo.v — self-checking testbench for the progress-demo test list
//  T0  PS/2 receiver + scan-code decoder (W make/break, arrow E0 74)
//  T1  1.1/1.2 eight directions -> facing state (sprite frame)
//  T2  1.3 boundary clamp (cannot leave the road)
//  T3  2.x item collision: collect pulse, sparkle frame, item disappears, counter changes
//  T4  3.1 evolution HORSE -> BIKE -> BENZ after 3 items each, BENZ saturates
`timescale 1ns/1ps
module tb_demo;
    reg clk = 0;  always #5 clk = ~clk;     // 100 MHz
    reg rst = 1;
    integer errors = 0;

    task check(input cond, input [8*64-1:0] msg);
        begin
            if (!cond) begin errors = errors + 1; $display("FAIL: %0s", msg); end
            else $display("pass: %0s", msg);
        end
    endtask

    // ---------------- T0: PS/2 ----------------
    reg ps2c = 1, ps2d = 1;
    wire [7:0] rx_byte; wire rx_done;
    wire k_up, k_down, k_left, k_right;
    ps2_rx      u_rx (.clk(clk), .rst(rst), .ps2_clk(ps2c), .ps2_data(ps2d), .rx_byte(rx_byte), .rx_done(rx_done));
    kbd_decoder u_kd (.clk(clk), .rst(rst), .rx_byte(rx_byte), .rx_done(rx_done),
                      .key_up(k_up), .key_down(k_down), .key_left(k_left), .key_right(k_right));

    task ps2_send(input [7:0] b);
        integer i; reg [10:0] fr;
        begin
            fr = {1'b1, ~^b, b, 1'b0};          // stop, odd parity, data, start
            for (i = 0; i < 11; i = i + 1) begin
                ps2d = fr[i]; #20000; ps2c = 0; #40000; ps2c = 1; #20000;   // ~12.5 kHz
            end
            #100000;
        end
    endtask

    // ---------------- DUT for T1..T4 ----------------
    reg tick = 0;
    reg mu = 0, md = 0, ml = 0, mr = 0;
    wire [2:0] dir; wire [9:0] px, py; wire [3:0] spd;
    wire [1:0] form, count; wire [7:0] total; wire evolve;
    facing_fsm  u_face (.clk(clk), .rst(rst), .tick(tick), .mv_up(mu), .mv_down(md), .mv_left(ml), .mv_right(mr), .dir(dir));
    player_move u_move (.clk(clk), .rst(rst), .tick(tick), .mv_up(mu), .mv_down(md), .mv_left(ml), .mv_right(mr),
                        .form(form), .px(px), .py(py), .spd(spd));

    wire [15:0] rnd;
    lfsr16 u_lfsr (.clk(clk), .rst(rst), .q(rnd));
    wire [9:0] ix, iy; wire ov, vis, popg, col;
    item_slot #(.INIT_WAIT(7'd85)) u_item (.clk(clk), .rst(rst), .tick(tick), .px(px), .py(py),
        .grant(ov), .clear(evolve), .rnd(rnd), .ix(ix), .iy(iy),
        .overlap(ov), .visible(vis), .popping(popg), .collect(col));

    reg extra_collect = 0;
    evolution u_evo (.clk(clk), .rst(rst), .collect(col | extra_collect), .form(form), .count(count),
                     .total(total), .evolve(evolve));

    task frame; begin @(posedge clk); tick <= 1; @(posedge clk); tick <= 0; repeat (6) @(posedge clk); end endtask
    task frames(input integer n); integer k; begin for (k = 0; k < n; k = k + 1) frame; end endtask
    task setmv(input u, input d, input l, input r); begin mu = u; md = d; ml = l; mr = r; end endtask
    task pulse_collect; begin @(posedge clk); extra_collect <= 1; @(posedge clk); extra_collect <= 0; @(posedge clk); end endtask

    integer seen_pop, seen_col, k;

    initial begin
        repeat (10) @(posedge clk); rst = 0; repeat (10) @(posedge clk);

        // T0
        ps2_send(8'h1D);                   check(k_up == 1,    "T0 W make -> key_up=1");
        ps2_send(8'hF0); ps2_send(8'h1D);  check(k_up == 0,    "T0 W break -> key_up=0");
        ps2_send(8'hE0); ps2_send(8'h74);  check(k_right == 1, "T0 arrow right (E0 74) -> key_right=1");
        ps2_send(8'hE0); ps2_send(8'hF0); ps2_send(8'h74); check(k_right == 0, "T0 arrow right break");

        // T1: eight directions
        check(dir == 3'd4, "T1 reset facing = S");
        setmv(1,0,0,0); frame; check(dir == 3'd0, "T1 up -> N (0)");
        setmv(1,0,0,1); frame; check(dir == 3'd1, "T1 up+right -> NE (1)");
        setmv(0,0,0,1); frame; check(dir == 3'd2, "T1 right -> E (2)");
        setmv(0,1,0,1); frame; check(dir == 3'd3, "T1 down+right -> SE (3)");
        setmv(0,1,0,0); frame; check(dir == 3'd4, "T1 down -> S (4)");
        setmv(0,1,1,0); frame; check(dir == 3'd5, "T1 down+left -> SW (5)");
        setmv(0,0,1,0); frame; check(dir == 3'd6, "T1 left -> W (6)");
        setmv(1,0,1,0); frame; check(dir == 3'd7, "T1 up+left -> NW (7)");
        setmv(0,0,0,0); frame; check(dir == 3'd7, "T1 release -> keep NW");

        // T2: clamp
        setmv(1,0,1,0); frames(300);
        check(px == 10'd128 && py == 10'd48, "T2 up-left wall: px=128, py=48");
        setmv(0,1,0,1); frames(300);
        check(px == 10'd480 && py == 10'd448, "T2 down-right wall: px=480, py=448");
        setmv(0,0,0,0);

        // T3: walk to the item once it spawns, expect collect + sparkle + disappear
        wait (vis == 1);
        $display("     item spawned at (%0d,%0d), player at (%0d,%0d)", ix, iy, px, py);
        seen_pop = 0; seen_col = 0;
        for (k = 0; k < 600 && !seen_col; k = k + 1) begin
            setmv(py > iy + 2, py + 2 < iy, px > ix + 2, px + 2 < ix);
            frame;
            if (col) seen_col = 1;
            if (popg) seen_pop = 1;
        end
        setmv(0,0,0,0);
        check(seen_pop == 1,   "T3 item touched -> sparkle frame (sprite changes)");
        check(count == 2'd1 && total == 8'd1, "T3 counter = 1 after pickup");
        frames(25);
        check(vis == 0,        "T3 item disappears after sparkle");

        // T4: evolution
        pulse_collect; check(form == 2'd0 && count == 2'd2, "T4 2 items -> still HORSE");
        pulse_collect; check(form == 2'd1 && count == 2'd0, "T4 3rd item -> BIKE, counter reset");
        check(spd == 4'd5, "T4 BIKE speed = 5");
        pulse_collect; pulse_collect; pulse_collect;
        check(form == 2'd2 && count == 2'd0, "T4 3 more -> BENZ");
        pulse_collect; pulse_collect; pulse_collect; pulse_collect;
        check(form == 2'd2 && count == 2'd3, "T4 BENZ is max, counter saturates at 3");

        if (errors == 0) $display("ALL TESTS PASSED");
        else             $display("%0d TEST(S) FAILED", errors);
        $finish;
    end
endmodule
