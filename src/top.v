
/*

https://gamefaqs.gamespot.com/snes/916396-super-nintendo/faqs/5395

       ----------------------------- ---------------------
      |                             |                      \
      | (1)     (2)     (3)     (4) |   (5)     (6)     (7) |
      |                             |                      /
       ----------------------------- ---------------------


        Pin     Description             Color of wire in cable
        ===     ===========             ======================
        1       +5v                     White
        2       Data clock              Yellow
        3       Data latch              Orange
        4       Serial data             Red
        5       ?                       no wire
        6       ?                       no wire
        7       Ground                  Brown

Every 16.67ms (or about 60Hz), the SNES CPU sends out a 12us wide, positive
going data latch pulse on pin 3. This instructs the ICs in the controller
to latch the state of all buttons internally. Six microsenconds after the
fall of the data latch pulse, the CPU sends out 16 data clock pulses on
pin 2. These are 50% duty cycle with 12us per full cycle. The controllers
serially shift the latched button states out pin 4 on every rising edge
of the clock, and the CPU samples the data on every falling edge.

        Clock Cycle     Button Reported
        ===========     ===============
        1               B
        2               Y
        3               Select
        4               Start
        5               Up on joypad
        6               Down on joypad
        7               Left on joypad
        8               Right on joypad
        9               A
        10              X
        11              L
        12              R
        13              none (always high)
        14              none (always high)
        15              none (always high)
        16              none (always high)

*/

module snes_controller_top (
    input sys_clk,
    input s1,

    output UART_TXD,
    output [1:0] led,

    output reg joy_latch,
    output joy_clk,
    input joy_data
);

wire mclk;                      // SNES master clock at 21.5054Mhz (~21.477)

gowin_pll_snes pll_snes (
    .clkout0(mclk),
    .clkout1(),
    .clkout2(),
    .clkin(sys_clk)             // 50 Mhz input
);

localparam FREQ = 21500000;
localparam TIME_6US = FREQ / 1000000 * 6;

reg joy_clk_reg = 1;
assign joy_clk = joy_clk_reg;

reg [2:0] state;
reg [$clog2(FREQ)-1:0] cnt;
reg [3:0] bits;
reg [15:0] btns;

`include "print.v"
defparam tx.uart_freq=115200;
defparam tx.clk_freq=FREQ;
assign print_clk = mclk;
assign UART_TXD = uart_txp;

always @(posedge mclk) begin
    cnt <= cnt + 1;

    case (state)
    3'd0: if (cnt == FREQ / 10) begin
        `print("Press S1\n", STR);
        state <= 1;
    end
    
    3'd1: /*if (s1)*/ begin
        cnt <= 0;
        state <= 2;
    end

    3'd2: begin         // send 12us-wide latch
        joy_latch <= 1;
        if (cnt == TIME_6US * 2 - 1) begin
            joy_latch <= 0;
            state <= 3;
            cnt <= 0;
            bits <= 0;
        end
    end

    3'd3: begin         // wait 6us, then joy_clk falls, sample bit
        if (cnt == TIME_6US - 1) begin
            joy_clk_reg <= 0;
            cnt <= 0;
            state <= 4;
            btns <= {btns[14:0], joy_data};
        end
    end

    3'd4: begin         // wait 6us, then joy_clk rises
        if (cnt == TIME_6US - 1) begin
            joy_clk_reg <= 1;
            cnt <= 0;
            bits <= bits + 1;
            if (bits == 4'd15)      // scan complete
                state <= 5;
            else
                state <= 3;
        end
    end

    3'd5: begin         // print result
        case (cnt[19:0])
        20'h00000: `print("\x0dSNES Buttons: ", STR);
        20'h10000: if (!btns[15]) `print("B ", STR);
                   else           `print("_ ", STR);
        20'h18000: if (!btns[14]) `print("Y ", STR);
                   else           `print("_ ", STR);
        20'h20000: if (!btns[13]) `print("Select ", STR);
                   else           `print("______ ", STR);
        20'h28000: if (!btns[12]) `print("Start ", STR);
                   else           `print("_____ ", STR);
        20'h30000: if (!btns[11]) `print("Up ", STR);
                   else           `print("__ ", STR);
        20'h38000: if (!btns[10]) `print("Down ", STR);
                   else           `print("____ ", STR);
        20'h40000: if (!btns[9])  `print("Left ", STR);
                   else           `print("____ ", STR);
        20'h48000: if (!btns[8])  `print("Right ", STR);
                   else           `print("_____ ", STR);
        20'h50000: if (!btns[7])  `print("A ", STR);
                   else           `print("_ ", STR);
        20'h58000: if (!btns[6])  `print("X ", STR);
                   else           `print("_ ", STR);
        20'h60000: if (!btns[5])  `print("L ", STR);
                   else           `print("_ ", STR);
        20'h68000: if (!btns[4])  `print("R ", STR);
                   else           `print("_ ", STR);
        20'h80000: begin
            cnt <= 0;
            state <= 6;
        end
        default: ;
        endcase
    end

    3'd6: begin         // wait 16ms, then start again
        if (cnt == FREQ / 1000 * 16) begin
            cnt <= 0;
            state <= 2;
        end
    end

    endcase

end

assign led = cnt[19:18];

endmodule